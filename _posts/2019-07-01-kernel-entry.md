---
layout: post
title:  "1001 Ways of Implementing a System Call"
categories: generic
author: julian
published: false
---

Today, we're going to look at the many ways of implementing user-to-kernel
transitions on x86, i.e. [system
calls](https://en.wikipedia.org/wiki/System_call). In the forty or so years of
x86, the architecture collected a large amount of legacy features and the system
call mechanisms are no exception. So, let's first quickly review what system
calls actually need to accomplish.

In modern operating systems there is a distinction between _user mode_
(executing normal application code) and _kernel mode_[^supervisor] (being able
to touch system configuration and devices). System calls are the way for
applications to request services from the operating system kernel and bridge the
gap. To facilitate that, the CPU needs to provide a mechanism for applications
to _securely_ transition from user to kernel mode.

Secure in this context means that the application cannot just jump to arbitrary
kernel code, because that would effectively allow the application to do what it
wants on the system. The kernel must be able to configure defined entry points
and the system call mechanism must enforce these. After the system call is
handled, the operating system also needs to know where to return to in the
application, so the system call mechanism also has to provide this information.

I came up with four mechanisms that match this description. I'm going to limit
this discussion to 64-bit only to leave the
[weirder](https://en.wikipedia.org/wiki/Task_state_segment)
[ones](https://en.wikipedia.org/wiki/Virtual_8086_mode) for another post.

1. Software Interrupts using the [`int` instruction](https://en.wikipedia.org/wiki/INT_%28x86_instruction%29)
1. [Call Gates](https://en.wikipedia.org/wiki/Call_gate_(Intel))
1. Fast system calls using `sysenter`/`sysexit` 
1. Fast system calls using `syscall`/`sysret`

Using _Software interrupts_ is the oldest mechanism we mention here. The key
idea is to use the same method to enter the kernel as hardware interrupts do. In
essence, it is still the mechanism that was introduced with [Protected
Mode](https://en.wikipedia.org/wiki/Protected_mode) in 1982 on the 286, but even
the earlier CPUs already had cruder versions of this.

Because interrupt vector `0x80` can still be used to invoke system
calls[^linuxint] on 64-bit Linux, we are going to stick with this example:

![Kernel Entry using a Software Interrupt](/assets/kernelentry-softint.svg)
{: style="text-align: center;"}

The processor finds the kernel entry address by taking the interrupt vector
number from the `int` instruction and looking up the corresponding descriptor in
the [Interrupt Descriptor
Table](https://wiki.osdev.org/Interrupt_Descriptor_Table) (IDT). This descriptor
will be an Interrupt or Trap Gate[^inttrap] to kernel mode and it contains the
pointer to the handling function in the kernel.

These kinds of transitions between different privilege levels using gates cause
the processor to switch the stack as well. The stack pointers for non-user
privilege levels are kept in the [Task State
Segment](https://wiki.osdev.org/TSS#x86_64_Structure)[^tss]. After switching to
the new stack, the processor pushes (among other information) the return address
and the user's stack pointer onto the kernel stack. A typical handler routine in
the kernel would then continue with pushing general purpose registers on the
stack as well to preserve them. The data structure that is created on the stack
during this process is called the _interrupt frame_.

To return to userspace[^useriret], the kernel executes an `iret` instruction
after restoring the general purpose registers. `iret` restore the user's stack
and execution continues after the `int` instruction that entered the kernel in
the first place.

Our second mechanism, the _Call Gate_ is very similar to using software
interrupts. Although Call Gates are the somewhat official way of implementing
system calls in the absence of the more modern alternatives discussed below, I'm
aware of no use except by
[malware](https://www.f-secure.com/v-descs/gurong_a.shtml).

I've highlighted the differences here:

![Kernel Entry using a Call Gate](/assets/kernelentry-callgate.svg)
{: style="text-align: center;"}

Instead of `int`, the user initiates the system call by executing a _far call_.
Far calls are left-overs from the x86 [segmented memory
model](https://en.wikipedia.org/wiki/X86_memory_segmentation) where a `call`
instruction doesn't only specify the instruction pointer to go to, but also
refers the memory segment the instruction pointer is relative to using a
`selector` (`0x18` in the example).

The processor looks up the corresponding segment in the [Global Descriptor
Table](https://en.wikipedia.org/wiki/Global_Descriptor_Table) and in our case
will find a Call Gate instead of an ordinary segment. The Call Gate specifies
the instruction pointer in the kernel just as the Interrupt Gate does. The
processor ignores the instruction pointer provided by the `call` instruction in
this case. The rest works similarly to the software interrupt case, except that
the kernel has to use a different instruction for the return path because of a
different stack frame layout created by the hardware.

TODO Explain why inefficient

TODO Syscall/Sysret

![Kernel Entry Microbenchmarks](/assets/kernelentry-measurements.svg)
{: style="text-align: center;"}


## Footnotes

[^supervisor]: _Supervisor_ and _supervisor mode_ are a rarely used synonyms for kernel and kernel mode, but you will find them in the [Intel SDM][intelsdm]. It also explains the term _hypervisor_.
[^linuxint]: Linux needs to offer `int 0x80` for compatibility with ancient 32-bit applications and it takes no steps to prevent 64-bit applications from using it. This is weird, because all 64-bit CPUs have at least support for the much faster `syscall`.
[^inttrap]: The only difference between interrupt and trap gate is that the former causes the processor to mask interrupts when traversing the gate. This is largely irrelevant for our discussion.
[^tss]: The TSS is a vestige from hardware-supported task switching support also introduced with the 286. This feature was never really used and AMD neutered it when they designed the 64-bit extension to x86.
[^useriret]: `iret` can also return to kernel mode. This is decided depending on the segment selectors that are pushed as part of `int`.

[intelsdm]: https://software.intel.com/en-us/articles/intel-sdm
