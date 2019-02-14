---
layout: post
title:  "Hiding Data in Redundant Instruction Encodings"
author: julian
published: true
---

<!--
    See this post in its final form via:
    bundle exec jekyll serve --incremental --unpublished
-->

As we've seen in the [previous post]({% post_url 2019-02-08-fingerprint %}), x86
instructions are encoded as variable-length byte strings. In this post, we will
explore how to covertly hide information in x86 instructions. For that, let's
dive a bit into how x86 instructions are encoded.

Let's look at two encodings for the same [`xor`
instruction](https://www.felixcloutier.com/x86/xor):

```nasm
; 35 01 00 00 00
xor eax, 1
; 81 f0 01 00 00 00
xor eax, 1
```

The above instructions do exactly the same. They take the `eax` register, xor
its value with 1, and store the result back in `eax`, yet they are encoded
differently.

For historical reasons, x86 has shorter encodings for some arithmetic
instructions when they operate on the `al/ax/eax/rax` "accumulator" registers as
opposed to any other general-purpose register. This is the first example. It has
a `35` opcode for `xor eax` and afterwards follows a 4-byte immediate value (1)
in [little-endian](https://en.wikipedia.org/wiki/Endianness#Little-endian)
order.

The second example uses the more generic `81` opcode byte, which has no
hard-coded first operand and instead needs a [ModR/M byte][modrm]. A ModR/M byte
can specify any register or memory operand. `F0` happens to specify the register
`eax`.

Semantically, both instructions are identical, yet they are encoded differently.
A decent assembler will never generate the second option, because it wastes one
byte of space. However, a disassembler generates the exact same textual
representation for these two instructions. Only by looking at the actual
instruction bytes can anyone see the difference.

It seems we have found our sneaky way of hiding data. We can embed one bit of
information into every `xor eax, ...` instruction by either using the short or
the long encoding of the instruction.

Let's put this knowledge into practice. I've crafted a [small program](https://github.com/blitz/x86.lol-examples/blob/master/steganography/main.cpp)
that contains lots of `xor` instructions operating on the `eax` register. I also
have a [Python script](https://github.com/blitz/x86.lol-examples/blob/master/steganography/embed.py)
that takes an assembly file and embeds a message bit-by-bit by switching between
the different encodings of `xor`.

The code for this example can be found on
[Github](https://github.com/blitz/x86.lol-examples/tree/master/steganography).

If you clone this repo, you can embed a secret message into the binary like
this:

```sh
% make main-secret
# Compile main.cpp to an assembly file
g++ -Os -std=c++14 -S -c main.cpp -o main.s
# Replace xor instructions
./embed.py "$(cat secret.txt)" < main.s > main.se
# Assemble the result into an object file
as main.se -o main-secret.o
# Finally, link everything into a normal executable.
g++ -Os -std=c++14 -o main-secret main-secret.o
```

We now have a binary `main-secret` that has the secret message engraved into its
`xor` instruction encodings. Regardless of the message, the binary contains the
same data and the same instructions, just not with the same encodings. It
behaves identically to a version of the program compiled normally. A casual look
at it with a reverse engineering tool reveals nothing out of the ordinary.

With `objdump` we can check what happened:

```
% objdump -dM intel main-secret | grep "xor.* eax,0" | head -n8
  40148b:	35 01 00 00 00       	xor    eax,0x1
  401493:	81 f0 02 00 00 00    	xor    eax,0x2
  40149c:	35 03 00 00 00       	xor    eax,0x3
  4014a4:	35 04 00 00 00       	xor    eax,0x4
  4014ac:	35 05 00 00 00       	xor    eax,0x5
  4014b4:	35 06 00 00 00       	xor    eax,0x6
  4014bc:	81 f0 07 00 00 00    	xor    eax,0x7
  4014c5:	35 08 00 00 00       	xor    eax,0x8
```

The script embeds the least significant bit first. So interpreting short
encodings as 0 and long encodings as 1, we get 01000010 in binary, which is 66
in decimal and 'B' in [UTF-8](https://en.wikipedia.org/wiki/UTF-8).

The [decode script](https://github.com/blitz/x86.lol-examples/blob/master/steganography/decode.py)
automates this process and reveals the full message that was apparently sent by
Gandalf:

```
% ./decode.py main-secret 
Bring the 💍 to the 🌋, Frodo!
```

He could now smuggle this message as a Debian package into the Shire.

This is only a toy example, but the same principle can be used to hide more data
in redundant instruction encodings for other x86 instructions. Even more data
can be hidden by exploiting the x86 processor's laissez-faire approach to
parsing [instruction
prefixes](https://wiki.osdev.org/X86-64_Instruction_Encoding#Legacy_Prefixes) or
multiple ways of encoding SIMD instructions, but this is left as an exercise for
the reader.

Maybe now is a good time to head over to [https://reproducible-builds.org/](https://reproducible-builds.org/).

[modrm]: https://wiki.osdev.org/X86-64_Instruction_Encoding#ModR.2FM_and_SIB_bytes
