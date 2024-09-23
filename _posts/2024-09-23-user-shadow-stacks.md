---
layout: post
title:  "Hardening C Against ROP: Getting CET Shadow Stacks Working"
categories: generic
author: julian
published: true
---

This post shows you how to use
[CET](https://www.intel.com/content/www/us/en/developer/articles/technical/technical-look-control-flow-enforcement-technology.html)
[user shadow stacks](https://lwn.net/Articles/885220/) on Linux. CET
is a hardening technology that mitigates typical memory unsafety
issues on x86. This post will not explain this security feature. If
you don't know what CET is, this post is probably not for you. For general
advice on hardening C/C++, check out [these
guidelines](https://best.openssf.org/Compiler-Hardening-Guides/Compiler-Options-Hardening-Guide-for-C-and-C++.html).

Back to CET shadow stacks. Recent distros, such as [NixOS
24.05](https://nixos.org/) and [Fedora
40](https://fedoraproject.org/), satisfy all the software
requirements. If you're not on one of these distros, you need to check
whether you have the following prerequisites:

- Linux 6.6 or later with `CONFIG_X86_USER_SHADOW_STACK=y`
- glibc 2.39 or later
- A CPU supporting CET shadow stacks:
  - Intel Tiger Lake or later (?)
  - AMD Zen 3 or later
- GCC 8 or later (clang also works)

With this out of the way, let's get it working. We use a tiny C
program `test.c` that simulates ROP:

```c
#include <stdio.h>

int hello()
{
  printf("Return address corruption worked!\n");
  return 0;
}

// "Smash" the stack to execute hello instead of returning directly. This
// should not work with shadow stacks.
int foo();
asm ("foo: mov $hello, %rax; push %rax; ret");

int main()
{
  foo();
  return 0;
}
```

Compile this program with `-cf-protection=return` (or `full`) to
enable shadow stack support:

```console
$ gcc -fcf-protection=return -o test test.c
```

If your toolchain is recent enough, you see that the binary is marked
as supporting shadow stacks:

```console
$ readelf -n test | grep SHSTK
	  Properties: x86 feature: SHSTK
```

Shadow stacks are _not_ enabled by default as of glibc 2.39. So without opting
in, the test program will not use shadow stacks:

```
$ ./test
Return address corruption worked!
```

You opt in to shadow stacks using a [glibc
tunable](https://www.gnu.org/software/libc/manual/html_node/Tunables.html). When
everything works, you'll see that the stack smashing is prevented:

```console
$ GLIBC_TUNABLES=glibc.cpu.hwcaps=SHSTK ./test
[1]    14520 segmentation fault (core dumped)  GLIBC_TUNABLES=glibc.cpu.hwcaps=SHSTK ./test
```

Now you can go out and try it out on more interesting software!
