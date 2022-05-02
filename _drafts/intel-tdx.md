---
layout: post
title:  "Intel TDX: Hypervisor as Firmware"
categories: generic
author: julian
published: true
---

This post discusses Intel's Trust Domain Extensions (TDX). This
instruction set extension is Intel's latest attempt at implementing a
[Trusted Execution Environment
(TEE)](https://en.wikipedia.org/wiki/Trusted_execution_environment).

The [previous post]({% post_url 2021-11-10-intel-security-tech %})
discussed older Intel security technologies, such as
[SGX](https://en.wikipedia.org/wiki/Software_Guard_Extensions). You
might want to re-read that post for context.

I'm assuming general knowledge about hardware virtualization on
x86. Specifically, I assume that you roughly know what [VM
exits](https://revers.engineering/day-5-vmexits-interrupts-cpuid-emulation/)
are and how [nested
paging](https://revers.engineering/mmu-ept-technical-details/) works at a
conceptual level.

This blog post has two parts. In the first part, I'm going to explain
what TDX does from a hypervisor engineer's perspective. The goal is to
give you enough overview knowledge to make sense of the [Intel
documentation](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-trust-domain-extensions.html). The
second part contains my personal opinion about it.

# What Intel TDX intends to do

The goal of Intel TDX is very similar to that of Intel SGX: The
ability to run code on systems where you trust neither the operating
system nor hypervisor. The difference is that SGX forces the
programmer into a very restricted programming model, while Intel TDX
runs full virtual machines (VMs).

In principle, the idea is neat. A cloud provider gives you the ability
to run your VM, but you don't have to trust the cloud provider. You
only have to trust Intel, which you do anyway, if you run your code on
an Intel CPU. As such, the cloud provider moves out of the [Trusted
Computing Base
(TCB)](https://en.wikipedia.org/wiki/Trusted_computing_base) for the
[integrity and
confidentiality](https://en.wikipedia.org/wiki/Information_security#Key_concepts)
of the service that your VM provides.

Just as Intel SGX, TDX does not help with availability. This is fine,
because if the cloud provider stops running your VM, you can just buy
compute time somewhere else.

So far so good. At this level, Intel TDX is much easier to explain
than Intel SGX. But the devil is in the implementation.

# The Intel TDX Module

Guaranteeing confidentiality and integrity of a whole VM without
trusting the hypervisor is hard. Intel has not solved this problem,
but moved the security-critical part of the hypervisor into the
firmware. Intel calls this piece of hypervisor firmware the _Intel TDX
Module_ (or TDX module for short).

When I say hypervisor from here on, I mean the "normal" hypervisor
(such as KVM or Hyper-V) that interacts with the TDX module.

The hypervisor sets up and interacts with VMs using what's effectively
a set of system calls to the TDX module. To do that, Intel introduces
a new instruction `SEAMCALL`, which we will discuss later. With these
system calls, the hypervisor can create VMs, add guest memory and
create vCPUs, while the TDX module takes the proper security
precautions.

The job of the TDX module is to protect the VM from the remaining
operating system. Let's look at how TDX protects guest memory and
guest register state from the hypervisor.

TDX prevents access to guest memory by encrypting it. To do that, TDX
employs [MKTME](https://en.wikichip.org/wiki/x86/tme). Intel extends
MKTME to protect confidentiality _and_ integrity of memory.

VM exits, such as EPT violations that occur for MMIO emulation,
typically require the hypervisor to access and modify the complete CPU
state including the instruction pointer. With this power the
hypervisor can just execute arbitrary code in the guest with chosen
input values by maliciously setting the instruction pointer and
general purpose registers.

Handling the VM exits without exposing guest register content to the
hypervisor is more subtle. To protect integrity and confidentiality of
the guest registers when a VM exit occurs, the TDX module must _not_
forward the exit to the hypervisor. Allowing the hypervisor to handle
VM exits would break the security properties.

To avoid this security hole, TDX forces guests to use what's also
effectively system calls to request emulation from the hypervisor. For
that Intel introduces the `TDCALL` instruction. Guests use `TDCALL` to
request MMIO emulation.

# TDX MMIO Emulation Example

To put everything in context, let's look at how the hypervisor runs a
vCPU and handles a MMIO request:

... TODO Overview diagram ...

The flow is as follows:

1. The hypervisor starts the vCPU by executing a `SEAMCALL`
   instruction to request a vCPU to run with the `TDH.VP.ENTER`
   function.
1. The TDX module retrieves the vCPU state and does the traditional
   `VMRESUME` to enter the guest.
1. The guest executes and requests emulation services using the
   `TDCALL` instruction with the `TDG.VP.VMCALL` function.
1. The TDX module reflects the guest's request back to the hypervisor
   as the return value of `SEAMCALL`.

There are more examples in the TDX documentation. See for example
section "10.1 VCPU Transitions" in the [Intel TDX Module Base
Specification
1.5](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-trust-domain-extensions.html).

# Handling Interrupts

The above example covers _synchronous_ exits from the guest. But to
drive the platform the hypervisor also needs to be able to interrupt
guests when timer or device interrupts happen.

TDX handles interrupts using _asynchronous_ exits. In this case, the
`SEAMCALL` from the hypervisor returns indicating that a host
interrupt (or similar) occured. After the hypervisor has finished
handling the interrupt, it continues guest execution using `SEAMCALL`.

When handling asynchronous events, the hypervisor does not get a
chance to directly modify any vCPU state.

# Securing the TDX Module

# Avoiding Attacks from the Hypervisor

# Worthless without Remote Attestation?


#
