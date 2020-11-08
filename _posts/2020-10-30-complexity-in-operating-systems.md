---
layout: post
title:  "Complexity in Operating Systems"
categories: generic
author: julian
published: true
---

Over the last years I've been working on very different operating
systems. Operating systems are usually incredibly complex beasts. I
think there are mainly three drivers of this complexity. Surprisingly
enough, neither of these is having to deal with hardware.

The first one is resource **discovery**, i.e. figuring out what the
computer the OS is running on actually looks like. On x86, this
involves parsing countless bitfields, tables, executing byte code
provided by the firmware, probing individual features, etc. The most
painful example of this I've seen so far is figuring out which
interrupt a particular PCI interrupt line is routed to. It's worth a
set of posts, but until then, feel free to checkout [this
description](https://habr.com/en/post/501912/). (If it's down, it's
also cached by
[Google](https://webcache.googleusercontent.com/search?q=cache:CXZUV61m7hwJ:https://habr.com/en/post/501912/+&cd=1&hl=en&ct=clnk).)

The second issue is **resource management**. Essentially, how do you
hand out and eventually reclaim all the resources you discovered. For
some workloads performance matters here, so this code is usually
written with speed in mind.

The third reason is that at compile time the **workload** is
unclear. So the kernel has to assume the worst. It must be ready to
start a couple of hundred VMs or create a thousand TCP sockets in a
blink of an eye, because there is no way to know what's going to
happen or what the actual requirements are.

A fun exercise is to checkout the [KVM code for creating
VMs](https://elixir.bootlin.com/linux/v5.9.1/source/virt/kvm/kvm_main.c#L739). Try
to follow
[the](https://elixir.bootlin.com/linux/v5.9.1/source/arch/x86/kvm/x86.c#L9904)
[code](https://elixir.bootlin.com/linux/v5.9.1/source/arch/x86/kvm/vmx/vmx.c#L7059)
to where the actual VM is created in hardware. *Spoiler:* There is
none. It's all figuring out what the platform can do and then setting
up a bunch of spinlock, mutexes, lists, arrays, structs, ...

I don't want to pick on KVM in particular. I think it's pretty ok as
far as Linux kernel code goes. Operating System kernel code is mostly
like this: A lot of really mind numbing platform discovery and
resource management code written for speed assuming the worst case
requirements in a language that doesn't do parsing, resource
management or concurrency well (among other things).

People take this all for granted. But when I look around, I see many
systems that don't need this complexity and where it is only a safety
and security burden. Consider most appliance-type products, e.g. a
Wi-Fi router. Or a system that runs one service on a cloud VM. You
know everything in advance!

If you read until this point, you are probably asking yourself, where
I am going with this. If you think [separation
kernel](https://en.wikipedia.org/wiki/Separation_kernel), you are
right. My rough plan to write a couple of more posts to flesh out the
idea of doing all the complicated OS parts at compile time and how
this results in an incredibly simple, secure, and efficient system at
runtime. There will be [RISC-V](https://riscv.org/),
[Haskell](https://www.haskell.org/), [Dhall](https://dhall-lang.org/),
and [Rust](https://www.rust-lang.org/) content.

Stay tuned.
