---
layout: post
title:  "Tell me Your Instruction Set"
categories: generic
author: julian
published: false
---

<!--
    See this post in its final form via:
    bundle exec jekyll serve --incremental --unpublished
-->

What instructions does my Intel CPU actually understand? That seems like a
simple question, because you can open the [Intel Software Developer's
Manual][intelsdm] and it will tell you what the CPU can do. But this only half
of the truth. The manual shows you how instructions _should_ be encoded, but the
arcane architecture will also happily execute instructions that the manual
doesn't mention or interpret some instructions differently than the astute
reader of the SDM might imagine.

This post will describe how to get the CPU to tell us what instruction it
understands and how this relates to reverse engineering processors,
virtualization security, and the almost impossible task of writing a correct x86
instruction decoding library. On the way, we'll build a toy operating system to
experiment with the x86 instruction set.

## Background: Instruction Sets

On the lowest software level, programs are encoded as binary streams of CPU
instructions. For most RISC CPU architectures, such as ARM, decoding
instructions is straight-forward. Take a random piece of 64-bit ARM code. Left
is the hexadecimal representation, to the right is the decoded instruction:

```
a9a57bfd        stp     x29, x30, [sp, #-432]!
aa0103e3        mov     x3, x1
a9025bf5        stp     x21, x22, [sp, #32]
912c4273        add     x19, x19, #0xb10
d2800004        mov     x4, #0x0
aa1403e3        mov     x3, x20
aa1303e2        mov     x2, x19
```

All instructions are 4 bytes long. You can even guess some of the encoding from
staring at a bit. The last bits of each `mov` instruction seem to encode the
destination register, for example.

So far, so nice, but let's look at a random set of x86 instructions as
comparison:

```
48 b8 00 00 fe ff ff ff ff 1f   movabs rax,0x1ffffffffffe0000
48 8d 97 00 00 fe ff            lea    rdx,[rdi-0x20000]
48 39 c2                        cmp    rdx,rax
b8 00 00 02 00                  mov    eax,0x20000
48 0f 46 c7                     cmovbe rax,rdi
31 d2                           xor    edx,edx
4c 89 e8                        mov    rax,r13
89 5c 24 04                     mov    DWORD PTR [rsp+0x4],ebx
```

Things have gotten significantly more complicated. Even in this tiny example,
there instructions from two to eleven bytes. Even register-to-register moves
don't have a consistent length anymore. The OSDev wiki has a decent introduction
on [x86 instruction encoding][osdevx86] that gives an overview of what's going
on. The definitive resources is the [Intel SDM] Vol 2. Appendix B "Instruction
Formats and Encodings", which clocks in at roughly 120 pages.

- give a very brief overview of instruction encoding

## Enumerating the Instruction Set with Sandsifter

<iframe width="560" height="315" src="https://www.youtube-nocookie.com/embed/KrksBdWcZgQ"
    frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture"
    allowfullscreen></iframe>

TODO:
 - describe how sandsifter probes instruction lengths
 - describe how sandsifter iterates through the instruction set
 
## Taking Sandsifter Native: Baresifter

- why would we implement this as a baremetal kernel?
  - baresifter is safe, i.e. can't accidentally destroy its own state
  - technically you can probe different CPU modi (16-bit, 32-bit, ...)
  - it's way faster
- how is it implemented?
- how long does it take to iterate through the instruction space?

## Outcomes

- AVX-512 decoding on Skylake, even though the CPU doesn't understand this
  instruction set extension
- Bugs in common disassembly libraries
- Fingerprinting processors and hypervisors

[intelsdm]: https://software.intel.com/en-us/articles/intel-sdm
[arm7isa]: http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.ddi0210c/CACCCHGF.html
[osdevx86]: https://wiki.osdev.org/X86-64_Instruction_Encoding
