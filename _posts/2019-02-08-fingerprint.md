---
layout: post
title:  "Fingerprinting x86 CPUs using Illegal Opcodes"
categories: generic
author: julian
published: true
---

x86 CPUs usually identify themselves and their features using the [`cpuid`
instruction](http://sandpile.org/x86/cpuid.htm). But even without looking at
their self-reported identities or timing behavior, it is possible to tell CPU
microarchitectures apart.

Take for example the `ud0` instruction. This instruction is used to generate an
[Invalid Opcode Exception (#UD)](http://sandpile.org/x86/except.htm). It is
encoded with the two bytes `0F FF`.

If we place this instruction at the end of an executable page in memory and the
following page is not executable, we see differences across x86
microarchitectures. On my [Goldmont
Plus](https://en.wikipedia.org/wiki/Goldmont_Plus)-based Intel
[NUC](https://en.wikipedia.org/wiki/Next_Unit_of_Computing), executing this
instruction will indeed cause an #UD exception. On Linux, this exception is
delivered as `SIGILL`.

If I retry the same setup on my
[Skylake](https://en.wikipedia.org/wiki/Skylake_(microarchitecture)) desktop,
the result is a `SIGSEGV` instead. This signal is caused by a page fault during
instruction fetch. This means that the CPU did not manage to decode this
instruction with just the two bytes and tried to fetch more bytes. My somewhat
older
[Broadwell](https://en.wikipedia.org/wiki/Broadwell_(microarchitecture))-based
laptop has the same behavior.

Using [baresifter](https://github.com/blitz/baresifter), we can reverse engineer
(more on that in a future blog post) that Skylake and Broadwell actually try to
decode `ud0` as if it had source and destination operands. After the the two
opcode bytes, they expect a [ModR/M
byte](https://wiki.osdev.org/X86-64_Instruction_Encoding#ModR.2FM) and as many
additional immediate or displacement bytes as the ModR/M byte indicate.

I have put the code for this example on
[Github](https://github.com/blitz/x86-fingerprint/blob/master/main.cpp).

Why would this matter? Afterall, this behavior is now even documented in the
[Intel Software Developer's Manual](https://software.intel.com/en-us/articles/intel-sdm):

> Some older processors decode the UD0 instruction without a ModR/M byte. As a
> result, those processors would deliver an invalid-opcode exception instead of
> a fault on instruction fetch when the instruction with a ModR/M byte (and any
> implied bytes) would cross a page or segment boundary.

I have picked an easy example for this post. Beyond this documented difference,
there are many other undocumented differences in instruction fetch behavior for
other illegal opcodes that makes it fairly easy to figure out what
microarchitecture we are dealing with. This still applies when a hypervisor
intercepts `cpuid` and changes the (virtual) CPU's self-reported identity. It is
also possible to fingerprint different x86 instruction decoding libraries using
this approach and narrow down which hypervisor software stack is used.

One usecase I can think of is to build malware that is tailored to recognize its
target using instruction fetch fingerprinting. Let's say the malware's target is
an embedded system with an ancient x86 CPU. If it is actively fingerprinting the
CPU, it can avoid deploying its payload in an automated malware analysis system
and be discovered, unless the malware analysis is performed on the exact same
type of system targeted by the malware.
