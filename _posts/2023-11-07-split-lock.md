---
layout: post
title:  "Split Lock Detection VM Hangs"
categories: generic
author: julian
published: true
---

Recently, I've noticed strange hangs of KVM VMs on a custom VMM. As it
fits the topic of this blog, I thought I make the issue more
googleable. Until we dive into the issue, we have to set the scene a
bit.

## The Scene

Consider that we want to run a KVM vCPU on Linux, but we want it to
unconditionally exit after 1ms regardless of what the guest does. To
achieve this, we can create a `CLOCK_MONOTONIC` timer with
[`timer_create`](https://man7.org/linux/man-pages/man2/timer_create.2.html)
that sends a signal to the thread that runs the vCPU (via
`SIGEV_THREAD_ID`). We choose `SIGUSR1`, but other signals work as
well.

We have to make sure that we do not receive the signal when the vCPU
does not execute. This is important, because then the signal will not
fulfill its goal of kicking the vCPU out of guest execution. For that,
we _mask_ `SIGUSR1` with
[`pthread_sigmask`](https://man7.org/linux/man-pages/man3/pthread_sigmask.3.html)
in the host thread and _unmask_ it for the vCPU via
[`KVM_SET_SIGNAL_MASK`](https://www.kernel.org/doc/html/v6.6/virt/kvm/api.html#kvm-set-signal-mask).

This setup works beautifully and in essence emulates the VMX
preemption timer[^preemptiontimer]. There is only one wart at this
point. When
[`KVM_RUN`](https://www.kernel.org/doc/html/v6.6/virt/kvm/api.html#kvm-run)
returns `EINTR`, because the timer signal was pending, we need to
"consume" the signal or the next `KVM_RUN` will immediately exit
again. We can do this with
[`sigtimedwait`](https://man7.org/linux/man-pages/man3/sigtimedwait.3p.html)
with a zero timeout.

## Weird VM Hangs

When I used this scheme on my Intel Tiger Lake laptop, I noticed
strange hangs in VMs. The VM would sometimes get stuck on one
instruction. The weird thing was that the vCPU could still receive and
_handle_ interrupts, but this one harmless looking instruction would
never complete. The effect was that some Linux kernel threads would
just get stuck while others continue to run.

The instruction in question was this from the
[`set_bit`](https://elixir.bootlin.com/linux/v5.4.259/source/arch/x86/include/asm/bitops.h#L60)
function of my Linux 5.4 guest:

```assembly
ffffffff810238b0 <set_bit>:
ffffffff810238b0:       f0 48 0f ab 3e          lock bts %rdi,(%rsi)
ffffffff810238b5:       c3                      ret
```

Way too late, I noticed the following warning in the host's kernel log
with a matching instruction point:

```
x86/split lock detection: #AC: vmm/61253 took a split_lock trap at address: 0xffffffff810238b0
```

[Split lock detection](https://lwn.net/Articles/790464/) is an
anti-DoS feature that can find or kill processes that perform
misaligned locked memory accesses, because they trigger extremely slow
paths in the CPU that impact the performance of other cores in the
system.

When I checked in more detail, the `lock bts` was indeed performing a
misaligned locked memory access, but why would this warning cause a permanent
hang at this instruction?

On my laptop running Linux 6.6, split lock detection was in its
default setting `warn`. This is reasonable, because the underlying
issue is not something you typically care about on a desktop
system. The
[documentation](https://www.kernel.org/doc/html/v6.6/admin-guide/kernel-parameters.html?highlight=split_lock_detection)
of the relevant kernel parameter reads as follows:

```
split_lock_detect=
   [X86] Enable split lock detection or bus lock detection

   When enabled (and if hardware support is present), atomic
   instructions that access data across cache line
   boundaries will result in an alignment check exception
   for split lock detection or a debug exception for
   bus lock detection.

...

   warn    - the kernel will emit rate-limited warnings
             about applications triggering the #AC
             exception or the #DB exception. This mode is
             the default on CPUs that support split lock
             detection or bus lock detection. Default
             behavior is by #AC if both features are
             enabled in hardware.
```

There were no clues about the hang here either. 🤔

## Going Deeper

When I checked the [kernel
function](https://elixir.bootlin.com/linux/v6.6/source/arch/x86/kernel/cpu/intel.c#L1172)
that emits the warning (called via
[`handle_guest_split_lock`](https://elixir.bootlin.com/linux/v6.6/C/ident/handle_guest_split_lock)),
the pieces started falling together:

```c
static void split_lock_warn(unsigned long ip)
{
	struct delayed_work *work;
	int cpu;

	if (!current->reported_split_lock)
		pr_warn_ratelimited("#AC: %s/%d took a split_lock trap at address: 0x%lx\n",
				    current->comm, current->pid, ip);
	current->reported_split_lock = 1;

	if (sysctl_sld_mitigate) {
		/*
		 * misery factor #1:
		 * sleep 10ms before trying to execute split lock.
		 */
		if (msleep_interruptible(10) > 0)
			return;
		/*
		 * Misery factor #2:
		 * only allow one buslocked disabled core at a time.
		 */
		if (down_interruptible(&buslock_sem) == -EINTR)
			return;
		work = &sl_reenable_unlock;
	} else {
		work = &sl_reenable;
	}

	cpu = get_cpu();
	schedule_delayed_work_on(cpu, work, 2);

	/* Disable split lock detection on this CPU to make progress */
	sld_update_msr(false);
	put_cpu();
}
```

When the host detects a split lock, it will try to punish the
offending thread by introducing a 10ms delay. But recall that our vCPU
has a 1ms timer pending!

The situation is thus the following:

1. The VMM programs a 1ms timer and starts guest execution with `KVM_RUN`.
2. The guest executes a misaligned `lock bts` and exits with an `#AC` exception.
3. The host Linux kernel sleeps for 10ms to punish this behavior.
4. The sleep is interrupted and **the function immediately returns**
   with split lock detection still enabled.

At this point, the VMM sees that 10ms has passed and processes its
timeout events. It programs a new timeout and we have the same
sequence of events again.

I have created a minimal example of this issue
[here](https://github.com/blitz/kvm-timer-demo). The [guest
code](https://github.com/blitz/kvm-timer-demo/blob/master/guest.asm)
just counts how many times it can can execute the `lock bts`
instruction.

When you execute this test program once with `split_lock_detect=warn`
and once with `split_lock_detect=off`, you get the following data:

![](/assets/2023-11-split-lock.png)

The plot shows number of loops that the guest finished on the vertical
axis and the pending timeout in ms on the horizontal axis.

You can clearly see that for timeouts below 10ms, this (artificial)
guest makes no progress at all when split lock detection is enabled!
On the other hand, when split lock detection is disabled, the guest
makes roughly as much progress as we give it time.

## Workarounds

As I already mentioned, the easiest workaround is to turn split lock
detection off via `split_lock_detect=off`. This is safe unless you run
a public cloud. Alternatively, the punishment can be disabled by
writing `0` into `/proc/sys/kernel/split_lock_mitigate`.

## A Bug?

The `split_lock_warn` function is clearly written to allow the
offender to make some progress. But in the situation where
`msleep_interruptible` is actually interrupted, this is not the case
anymore. It looks like a bug to me.

It's a difficult question what the correct behavior should be here. If
`msleep_interruptible` managed to sleep at least a bit (i.e. some
punishment was dealt), we should still go into the lower part of the
function that disables split lock detection and allow for forward
progress. This may make it possible to circumvent this punishment
though.

[^preemptiontimer]: I couldn't find a good resource to link here. The
    VMX preemption timer is a simple timer that counts down a value in
    the VMCS proportional to the TSC frequency and generates a VM exit
    when it reaches zero. See chapter 24.5.1 "VMX-Preemption Timer" in
    the [Intel
    SDM](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html).
