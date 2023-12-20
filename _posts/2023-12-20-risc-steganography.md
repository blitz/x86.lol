---
layout: post
title:  "RISC-V: The (Almost) Unused Bit in JALR"
author: julian
published: true
---

In the [RISC-V](https://en.wikipedia.org/wiki/RISC-V) architecture,
you have excellent support for embedding information into code by
choosing compressed or uncompressed instructions. While being a
typical
[RISC](https://en.wikipedia.org/wiki/Reduced_instruction_set_computer)
with fixed 32-bit instruction length, RISC-V allows certain common
instructions to be encoded as _compressed_ 16-bit instructions to
improve code density. Each compressed instruction has a functionally
identical 32-bit cousin.

If you are interested in how that is used to embed information into a
binary, you can check out my [x86 instruction set steganography]({%
post_url 2019-02-12-steganography %}) post from a couple of years ago,
which uses a similar property of the x86 instruction set to do exactly
this.

What I found more interesting, when reading the [RISC-V User-Level
ISA](https://riscv.org/wp-content/uploads/2017/05/riscv-spec-v2.2.pdf)
specification, is that the `jalr` ("Jump and Link Register")
instruction has an essentially unused bit that can be used to embed
information as well.

To see why this bit is essentially unused, consider how `jalr`
works. `jalr` computes its jump target by adding an immediate value to
a source register. This immediate is unlike other jump immediates
_not_ encoded as multiples of 2. The specification says that the
lowest bit of the sum is ignored and treated as zero. Since the source
register is practically always aligned and its lowest bit is zero,
this means that the lowest bit of the `jalr` is ignored in practice.

That there is a unused bit in the instruction encoding is unusual.
Typically, all the available space is used to encode bigger
immediates. But for the `jalr` instruction the RISC-V designers
decided to go for simplicity. Here is an excerpt from the
[spec](https://riscv.org/wp-content/uploads/2017/05/riscv-spec-v2.2.pdf)
(page 16):

> Note that the JALR instruction does not treat the 12-bit immediate as multiples of 2 bytes,
> unlike the conditional branch instructions. This avoids one more immediate format in hardware.
> In practice, most uses of JALR will have either a zero immediate or be paired with a LUI or
> AUIPC, so the slight reduction in range is not signiﬁcant.
>
> The JALR instruction ignores the lowest bit of the calculated target address. This both
> simpliﬁes the hardware slightly and allows the low bit of function pointers to be used to store
> auxiliary information. Although there is potentially a slight loss of error checking in this case,
> in practice jumps to an incorrect instruction address will usually quickly raise an exception.

The nice thing about this unused bit is that we can use it to embed
information without changing the size of the instruction itself. This
makes it more useful than selecting different-length encodings of the
same instruction, because we can do so _after_ compiling an
application. Choosing different instruction sizes has to be done at
compilation time, because it will shift around function addresses and
jump targets.

Of course, this only works as long as no one is actually storing
information in the low bit of function pointers. But this is rare in
practice.

So how much information can we embed using this method? Let's look at
GCC as a medium-sized application. Let's see how much we have to work
with for a RISC-V 32-bit GCC:

```console
$ readelf -l gcc

Elf file type is EXEC (Executable file)
Entry point 0x292bc
There are 11 program headers, starting at offset 52

Program Headers:
  Type           Offset   VirtAddr   PhysAddr   FileSiz MemSiz  Flg Align
  PHDR           0x000034 0x00010034 0x00010034 0x00160 0x00160 R   0x4
  INTERP         0x000194 0x00010194 0x00010194 0x00075 0x00075 R   0x1
  RISCV_ATTRIBUT 0x1948c6 0x00000000 0x00000000 0x00057 0x00000 R   0x1
> LOAD           0x000000 0x00010000 0x00010000 0x18e47c 0x18e47c R E 0x1000 <
  LOAD           0x18eb38 0x0019fb38 0x0019fb38 0x05d7c 0x0a290 RW  0x1000
  DYNAMIC        0x192ee8 0x001a3ee8 0x001a3ee8 0x00118 0x00118 RW  0x4
  NOTE           0x00020c 0x0001020c 0x0001020c 0x00020 0x00020 R   0x4
  TLS            0x18eb38 0x0019fb38 0x0019fb38 0x00000 0x00008 R   0x4
  GNU_EH_FRAME   0x1566d4 0x001666d4 0x001666d4 0x07b34 0x07b34 R   0x4
  GNU_STACK      0x000000 0x00000000 0x00000000 0x00000 0x00000 RW  0x10
  GNU_RELRO      0x18eb38 0x0019fb38 0x0019fb38 0x044c8 0x044c8 R   0x1
```

There are `0x18e47c` bytes of executable code (the `LOAD` segment with
**E**xecute permission). So there are roughly 1.5 MiB of code to work
with. Let's see how much `jalr` instructions we have:

```console
$ objdump -Mno-aliases -d gcc | grep -E "[^.]jalr" | wc -l
190
```

There are 190 `jalr` instructions in these 1.5 MiB of code. That means
we can embed 190 bits using this method into GCC. Not a lot. It turns
out that `jalr` almost exclusively used for [function entry stubs in
the
PLT](https://github.com/riscv-non-isa/riscv-elf-psabi-doc/blob/master/riscv-elf.adoc). So
there is also no hope of orders of magnitude more in larger binaries.

If we use the obvious method of switching between compressed
instructions and normal instructions in RISC-V we have much more to
work with. Let's count the compressed instructions in the GCC binary:

```console
$ objdump -Mno-aliases -d gcc | grep -F "c." | wc -l
186412
```

That make makes 186412 bits of information (around 23 KiB). Much more
useful!

Finally, why would you want to embed information into binaries? I can
only think of contrived examples, but they are fun. Consider an
air-gapped build system that produces signed binaries. You can only
put source code in on one side and you get a signed binary out on the
other side. An attacker that manages to exploit this system can
covertly smuggle the signing key out by embedding it into the signed
binaries itself!

Maybe it is time to insist on [reproducible
builds](https://reproducible-builds.org/) instead of air-gapped build
systems. 😼

