---
layout: post
title:  "RISC-V Stumbling Blocks"
categories: generic
author: julian
published: true
---

Recently, I've started to explore [RISC-V](https://risc-v.org/). I
experienced the journey as pretty refreshing, particularly because
I've been working on x86 low-level software almost exclusively for
about 10 years.

In this post, I want to quickly go over some high-level stumbling
blocks I noticed as I was starting out. I'm probably going to write
about more technical differences in subsequent blog posts.

While reading the rest of this post, please keep in mind: **RISC-V is
simple!** If you managed to do any low-level coding on x86, you will
find your way around RISC-V with little effort. It's easy to forget
how crazy some parts of x86 are. Just see my past posts.

## Choosing a Development System

If you want to do any OS work, you need a system that implements the
[Privileged ISA](https://riscv.org/specifications/privileged-isa).
Supporting the Privileged ISA is synonymous to being able to run
UNIX-like systems, because it brings user-/supervisor-mode distinction
and paging. Working on real hardware is generally preferred to working
in emulators, because the code eventually has to run on metal anyway
and emulators can be too forgiving for certain classes of problems.

There is a plethora of RISC-V microcontrollers for a couple of dollars
that all don't support the Privileged ISA. At the time of writing, the
only board you can buy that does support it is the $1000 [HiFive
Unleased](https://www.sifive.com/boards/hifive-unleashed), which was
beyond my "I just want to play around with this" budget.

The next most realistic option is an FPGA emulating one of the
open-source RISC-V implementations. [BOOM](https://boom-core.org/) in
particular looks interesting, because it supports everything you need
to get Linux going on it. Unfortunately, setting up the whole tooling
to build and deploy BOOM on a FGPA or simulator is also sufficiently
demotivating to make this viable for a hobby OS project.

Emulators seem to be the most sane way of trying out RISC-V at this
point. The two options I found are
[Spike](https://github.com/riscv/riscv-isa-sim) and, of course,
[Qemu](https://www.qemu.org/).

Spike works, but is weird. First, there is no documentation of the
machine it emulates and you have to go read the source code. The
serial console in particular is strange and I'm [not the only
one](https://riscv.org/2019/02/fosdem-video-lessons-learned-from-porting-helenos-to-risc-v-pros-cnd-cons-of-risc-v-from-a-microkernel-os-point/)
to point this out.

Qemu turned out to be the emulator of choice, because its machine
model is easily explorable (type `info mtree`) and because recent
versions include [OpenSBI](https://github.com/riscv/opensbi) as a
firmware by default (`-bios default`). Exploring the machine model
quickly answers questions like where to find RAM and OpenSBI is
helpful in getting early console output.

Problematic is that there is lots of misleading documentation out
there and that makes it look complicated to boot a simple ELF image
that wants to speak to a working
[SBI](https://github.com/riscv/riscv-sbi-doc/blob/master/riscv-sbi.adoc)
implementation. In Qemu >=4.1, this is as easy as `qemu-system-riscv64
-M virt -bios default -device loader,file=kernel.elf`.

## Documentation

Coming from the x86 world, you expect a gigantic PDF that tells you
everything you need to know: The [Intel Software Developer's
Manual][intelsdm]. Given the complexity of x86, this document actually
does a good job of telling you what you need to know.

RISC-V documentation relevant for kernel development is split between
the Privileged and Unprivileged ISA
[specifications](https://riscv.org/specifications/). This leads to
weird situations, for example when trying to figure out how `ecall`
(basically the system call instruction) works.

The instruction itself is documented in the Unprivileged ISA, but
there you find no details about what it actually does. The Privileged
ISA enumerates the instruction again and gives a high-level
description. It's then up to careful reading of the CSR description to
see what actually happens, specifically with interrupt masking.

If you compare this to the Intel SDM's description of the `syscall`
instruction, it's pretty straight-forward to figure out what's going
on. You go to the *one* list of all instructions and find
`syscall`. You read the pseudo-code description and it mentions all
changes to system state and every `MSR` that is
involved. Additionally, there is a list of what exceptions will be
caused in what situations.

This is my main problem with the state of RISC-V documentation so
far. Everything feels scattered. But don't get me wrong: Because
everything is also pretty simple, you will eventually piece it
together. The worst case is trying to get the bigger picture from
Linux source code comments.

## Parting Words

If this post sounded overly negative, this is not intended. I'm
personally very excited about RISC-V and its possiblities. If the
amount of assembly I have to write to get a toy kernel going is any
indication, RISC-V wins hands down.

The hurdles with hardware availability and documentation will go away
over time. Eventually there will be cheap development boards (a
Raspberry Five would be nice) and the
[OSDev](https://wiki.osdev.org/Main_Page) Wiki will catch up to
RISC-V. This will make this already very approachable architecture
even easier to work with for beginners.

Stay tuned for more RISC-V content from an x86 angle in future posts.

## Update (2020-01-07)

A reader [pointed out](https://github.com/blitz/x86.lol/issues/5) that
there is also the [Renode](https://renode.readthedocs.io/en/latest/)
simulator that has support for the HiFive Unleashed board. Looks
interesting!

[intelsdm]: https://software.intel.com/en-us/articles/intel-sdm
