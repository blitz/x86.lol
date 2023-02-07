---
layout: post
title:  "Intel MPX, CET, SGX, WTF"
categories: generic
author: julian
published: true
---

If you are confused about the different security technologies in
modern Intel CPUs, you have come to the right place. I'm going to
attempt to give a really brief overview. This is not an in-detail
hardcore technical discussion. The goal is just to give a brief
informal overview what problem each technology solves.

# Intel MPX: Memory Protection Extensions

We live in a world, where an uncomfortable amount of software is
written in
[unsafe](https://en.wikipedia.org/wiki/C_(programming_language))
[programming languages](https://en.wikipedia.org/wiki/C%2B%2B). It
would be nice if the CPU with help from the compiler can bounds check
memory accesses and take some out of the danger out of running these
programs.

With MPX, the compiler generates special MPX [bounds
check](https://en.wikipedia.org/wiki/Bounds_checking) instructions
that are [NOPs](https://en.wikipedia.org/wiki/NOP_(code)) on system
not supporting MPX. On systems that do support MPX, you get all the
benefits of the CPU checking whether memory accesses are actually
touching the memory they are allowed to. The idea is that the software
vendor can ship a single binary to everyone and people using
MPX-capable CPUs live a more secure life.

Intel MPX is deprecated and support for it is disappearing. The world
has decided that software-only methods, such as
[ASAN](https://en.wikipedia.org/wiki/AddressSanitizer) and friends do
a better job at finding memory unsafety.

# Intel CET: Control Flow Enforcement

We live in a world, where an uncomfortable amount of software is
written in
[unsafe](https://en.wikipedia.org/wiki/C_(programming_language))
[programming languages](https://en.wikipedia.org/wiki/C%2B%2B). It
would be nice if the CPU with help from the compiler can validate that
programs only execute code that they are supposed to
execute. Specifically, [ROP
attacks](https://en.wikipedia.org/wiki/Return-oriented_programming)
work by jumping to snippets of executable code that should not
actually be jumped to.

Consider an attacker that is able to control the value of a function
pointer through a buffer overflow. To ensure that code that uses this
function pointer can only jump to known jump targets, the CPU supports
a new instruction `ENDBR`. [Jump
targets](https://en.wikipedia.org/wiki/Indirect_branch) must start
with this `ENDBR` instructions or the CPU will raise an
exception. This limits an attack to only jump to valid jump targets
instead of freely choosing what code to execute.

Similarly, with CET the CPU also keeps a shadow stack to defend
against malicious function return addresses on the stack. In a
nutshell, the CPU keeps a inaccessible shadow copy of all return
addresses in addition to the normal program stack. When the CPU pops a
return address from the stack, the CPU will also consult the shadow
stack to see whether the return address was tampered with.

Like MPX, CET is only a bandaid over insecure software and cannot make
it secure. CET can only make exploitation hard. As such, CET is a
worthwhile tool to protect legacy code, but eventually all that legacy
code needs to be rewritten in safer languages.

# Intel SGX: Software Guard Extensions

We live in a world, where most code runs on infrastructure that is not
trusted by the author of the code. Consider the [Digital Restrictions
Management](https://fsfe.org/activities/drm/drm.en.html) (DRM)
usecase: A video streaming service wants to prevent users from
creating copies of videos they have paid for. Another (better)
usecase is holding on to secret keys even when the system where these
keys are used on is fully exploited. Maybe you want to keep your
crypto keys for yourself, even if the cloud provider that runs your
code is untrustworthy.

SGX allows creation of "enclaves" whose state live in encrypted memory
(when it is not currently in registers or various CPU caches). These
enclaves only have distinct entry and exit points to the "insecure"
world around it. Otherwise, they are a black box. The main selling
point is that even the operating system kernel cannot peek into
enclaves. The OS is still in control of executing enclaves, though, so
SGX cannot guarantee
[availability](https://en.wikipedia.org/wiki/Information_security#Key_concepts).
It does a good job at protecting integrity and confidentiality of data
in enclaves (caveats below).

Of course, you cannot use the now untrusted operating system to load
any secrets into enclaves. For this SGX, enables the usual [Trusted
Computing](https://en.wikipedia.org/wiki/Trusted_Computing) concepts,
such as Remote Attestation (proving to other systems that the enclave
runs a specific set of software on a real Intel CPU) and Sealed
Storage (storing data in a way so that only the "right" enclave can
access it). With this an enclave can prove its legitimacy to a server
over the network, receive crypto material and keep it safe.

SGX was hit in the nuts pretty hard by the whole lot of CPU
vulnerabilities. Check out [Foreshadow](https://foreshadowattack.eu/),
[Plundervolt](https://plundervolt.com/), [Load Value
Injection](https://lviattack.eu/), …

Besides the hardware security issues, there are also unique attack
methods that would not be in the attacker model for other
technologies. Because the operating system can freely schedule
enclaves how it wants, enclaves can be [effectively
single-stepped](https://github.com/jovanbulck/sgx-step). Single-stepping
enclaves allows for fine grained observation of changes to
microarchitectural state. This in turn allows attackers to leak
secrets from enclaves when they use libraries that are
[vulnerable](https://www.bearssl.org/constanttime.html) to these kinds
of attacks.

Let's leave the security issues behind and look at the programmer
experience. The enclave programming model is involved. You have to
create something like
[RPC](https://en.wikipedia.org/wiki/Remote_procedure_call) entry
points into your enclave code. And code that runs in enclaves, is not
magically secure. So any vulnerability in your enclave code can be
used to exfiltrate any secrets the enclave tries to protect.

In addition, SGX only works on operating systems that are SGX
enabled. Linux [only
recently](https://www.phoronix.com/scan.php?page=news_item&px=Intel-SGX-Linux-5.11)
gained support for SGX, for example. If you don't target Linux or
Windows, there's no SGX for you.

So all in all there is a lot of caveats to this Intel-only security
feature that might not warrant the large investment in architecting
software for SGX.

So if you are betting the bank on keeping secrets, you might be better
served with well-understood technologies, such as smartcards or
[hardware security
modules](https://en.wikipedia.org/wiki/Hardware_security_module)
(HSMs).

For those that still want to venture into trusted execution
environments, such as SGX, it's advised to choose an abstraction that
takes some of the pain away and also allows to target competing
technologies by other vendors. One example is
[Enarx](https://enarx.dev/).

# Upcoming

Next time, I'll discuss Intel MKTME and TDX. Do you have questions or
suggestions for other Intel CPU technologies to write about? Ping me
on [Twitter](https://twitter.com/blitzclone/).

# Update 2021-11-14

I've revised the SGX section and incorporated [feedback
from](https://twitter.com/_msw_/status/1458843278892146708)
[msw](https://twitter.com/_msw_/status/1458846427090538499) regarding
SGX security.
