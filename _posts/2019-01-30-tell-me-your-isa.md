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
experiment with the x86 instruction set. Before we get there, though, let's
start with some background.

## Background: Instruction Sets

On the lowest software level, programs are encoded as binary streams of CPU
instructions. For most RISC CPU architectures, such as ARM, decoding
instructions is straight-forward. Take a random piece of 64-bit ARM code. Left
is the hexadecimal representation, to the right is the decoded instruction[^1]:

[^1]: Use `objdump -d some-elf-file` to disassemble binaries on your system.
    `objdump -d -M intel some-elf-file` gives you x86 disassembly in Intel as
    opposed to AT&T syntax.

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
on. The definitive resource is the [Intel SDM][intelsdm] Vol 2. Appendix B
"Instruction Formats and Encodings", which clocks in at roughly 120 pages.

For a typical instruction in 64-bit mode, the instruction encoding breaks down
into the following components:

| Component       | Length (bytes)    | Description                                           |
| -------------   | -------------     | -                                                     |
| Legacy prefixes | 1 each (optional) | Specify address/data width, repetition, segments, ... |
| REX prefixes    | 1 (optional)      | Specify extended registers, 64-bit operands           |
| Opcode          | 1-3               | Encodes the actual instruction to be executed         |
| ModR/M          | 1 (if required)   | Specify address mode of memory operands               |
| SIB             | 1 (if required)   | Additional Scale-Index-Base for some addressing modes |
| Displacement    | 1, 2, 4           | Memory operand displacement                           |
| Immediate       | 0, 1, 2, 4        | Immediate data (hardcoded integer arguments)          |

Let's look at the following instruction from the above example:

`48 8d 97 00 00 fe ff`
{: style="text-align: center;"}

The first byte we read `48` is a REX prefix[^rex], because it falls within `40`
and `4F`. Because bit 3 (W) is set in the REX prefix, we know this is going to
be an instruction with a 64-bit operand.

After the REX prefix, opcode bytes must follow. So we fetch another byte `8d`
and look into the opcode table in the manual[^opcodes]. It tells us, this is an
instruction with one opcode byte (so we don't have to fetch more) and that this
instruction is `lea Gv, M`. The `G` says, that the register field in the ModR/M
byte will specify our destination register. `v` indicates that the operand maybe
16, 32, or 64-bits depending of the operand size of the instruction. We already
know from the REX prefix, that our operand is going to be 64-bit. `M` says that
the ModR/M byte will encode a memory source operand.

As the opcode is completely fetched, we fetch `97` as ModR/M byte. Looking at
the ModR/M decoding table[^modrm], we find the register field to be 4. We know
it's our destination register and it needs to be 64-bit. The fourth[^regorder] 64-bit
register is `rdx`.

The ModR/M byte also tells us the encoding of our memory address source operand
as register 7 plus a 32-bit displacement without a SIB byte or an immediate.
Because we are in 64-bit mode and nothing told us otherwise, our address width
is 64-bit. The seventh 64-bit register is `rdi`.

Finally, we need to fetch the 32-bit displacement mentioned in the ModR/M byte.
This is `00 00 fe ff`. x86 is a little-endian architecture, so this is
0xfffe0000. Displacements are also signed values[^twoscomplement] and so the
displacement is actually -0x20000.

As there is no immediate value to fetch, we are done with reading instruction
bytes and can put everything together together to get `lea rdx, [rdi +
0x20000]`. And this is just a _normal_ integer x86 instruction.

[^regorder]: The x86 registers have the following order: RAX, RCX, RDX, RBX, RSP, RBP, RSP, RSI, RDI. Looking up simple x86 facts is best done on [sandpile.org](http://sandpile.org).
[^rex]: The REX prefix is described in the Intel SDM Vol. 2 Chapter 2.2.1.2
[^opcodes]: The opcode tables are in Intel SDM Vol. 2 Appendix A.
[^modrm]: ModR/M encodings are found in Intel SDM Vol 2. Chapter 2.1.5. In this case, we are looking at Table 2-2.
[^twoscomplement]: x86 represents signed values as [Two's Complement](https://en.wikipedia.org/wiki/Two%27s_complement).

Of course, it gets more complicated. [AVX][avx] introduced a replacement for the
REX prefix with the VEX prefix that can be from one to three bytes long and
replaces most other prefixes. VEX was designed to be extensible, but then Intel
introduced yet another instruction encoding with [AVX-512][avx512] (EVEX
prefixes). This results in, for example, some instructions having multiple
distinct ways of encoding them.

This is already messy enough, but there are special cases in the instruction set
that don't really fit in any nice scheme at all. For example, `movabs` is the
only instruction with an 8-byte immediate value. Or there are legacy prefixes
that are re-used in SSE instructions to modify them. The `repnz`
(Repeat-Non-Zero) legacy prefix that switches a `addps` (add packed single
float) instruction to a `addpd` (add packed double float) instruction. Also
segment selector overrides have been re-used as branch-taken/branch-not-take
hints that have since been abandoned. The list goes on. It's just plain crazy.

All of this raises some questions:

- Is the Intel manual listing all instructions the CPU understands?
- Is any instruction decoding library correctly handling this mess?
- Does any of this have security implications?

Mild spoilers: No/No/Probably. :)

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
- difference in VSIB encoding in 16-bit protected vs real mode?

## Footnotes

[intelsdm]: https://software.intel.com/en-us/articles/intel-sdm
[arm7isa]: http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.ddi0210c/CACCCHGF.html
[osdevx86]: https://wiki.osdev.org/X86-64_Instruction_Encoding
[avx]: https://en.wikipedia.org/wiki/Advanced_Vector_Extensions
[avx512]: https://en.wikipedia.org/wiki/AVX-512
