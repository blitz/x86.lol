---
layout: post
title:  "1001 Ways of Implementing a System Call"
categories: generic
author: julian
published: false
---

Today, we're going to look at the many ways of implementing user-to-kernel
transitions, i.e. [system calls](https://en.wikipedia.org/wiki/System_call), on
x86. In the forty or so years of x86, the architecture collected a large amount
of legacy features and the system call mechanisms are no exception. So, let's
first quickly review what system calls actually need to accomplish.

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
application, so the system call mechanism also has to provide this information
to the kernel.

I came up with four mechanisms that match this description. I'm going to limit
this discussion to 64-bit only to leave the
[weirder](https://en.wikipedia.org/wiki/Task_state_segment)
[ones](https://en.wikipedia.org/wiki/Virtual_8086_mode) for another post.

1. Software Interrupts using the [`int` instruction](https://en.wikipedia.org/wiki/INT_%28x86_instruction%29)
1. [Call Gates](https://en.wikipedia.org/wiki/Call_gate_(Intel))
1. Fast system calls using `sysenter`/`sysexit` 
1. Fast system calls using `syscall`/`sysret`

Using _Software interrupts_ is the oldest mechanism we mention here. The key
idea is to use the same method to enter the kernel as hardware interrupts do. Even
in [Real Mode](https://en.wikipedia.org/wiki/Real_mode) times, this was the way
to request services from the operating system. The mechanism has changed from
the 8086 to the 286 due to the introduction of [Protected
Mode](https://en.wikipedia.org/wiki/Protected_mode) and was extended in the 386
to 32-bits and later to 64-bits. But in essence it is still the mechanism that
was introduced in 1982 with the 286.

![Kernel Entry using a Software Interrupt](/assets/kernelentry-softint.svg)
{: style="text-align: center;"}

TODO Write rest...

## Footnotes

[^supervisor]: _Supervisor_ and _supervisor mode_ are a rarely used synonyms for kernel and kernel mode, but you will find them in the [Intel SDM][intelsdm]. It also explains the term _hypervisor_.

[intelsdm]: https://software.intel.com/en-us/articles/intel-sdm
