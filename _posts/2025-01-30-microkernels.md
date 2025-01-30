---
layout: post
title:  "FOSDEM Edition: Thoughts on the Microkernels"
categories: generic
author: julian
published: true
---

It's [FOSDEM](https://fosdem.org/2025/) time!  I have fond memories of
the [Microkernel and Component-based OS
devroom](https://fosdem.org/2025/schedule/track/microkernel/) in
particular. It's a fun meetup of extremely skilled low-level software
engineers. This year I cannot attend, so it's a good time to
~~ramble~~ reflect on it.

## Some Background

The community around this devroom has one epicenter in Dresden, where
many of us met at the [Operating Systems
Group](https://tu-dresden.de/ing/informatik/sya/professur-fuer-betriebssysteme?set_language=en)
at the university. Dresden has a lively systems community, and
microkernel enthusiasts are a big part of it. For a large part of my
professional life, I was working on microkernel-based systems, too.

[Microkernel](https://en.wikipedia.org/wiki/Microkernel)-based systems
are appealing. They result naturally, if you take the idea of Least
Privilege to its logical end. They also arise naturally, if you
architect an operating system in a rigorously
[modular](https://wstomv.win.tue.nl/edu/2ip30/references/criteria_for_modularization.pdf)
fashion.

On paper systems based on microkernels promise clean architecture and
extremely secure systems due to a tiny [Trusted Computing
Base](https://en.wikipedia.org/wiki/Trusted_computing_base). In
reality, despite the conceptual advantages, the microkernel-based
systems struggle to achieve traction outside of niches.

## The Problem

Some years ago, I sat in a bar with a friend from the microkernel
community. We talked a long time about the issues in the
community. Despite the common goal of a component-based and secure
systems in the community, the point he made was that the inability to
work together is self-limiting for each project. Instead of everyone
collaborating towards the common goal, each company is reinventing the
wheel. Developers are excited to implement a new
[IPC](https://en.wikipedia.org/wiki/Inter-process_communication) path
that shaves five cycles off compared to the other microkernel's IPC
path or boast about their small TCB, even though this rarely works
towards what users would actually need.

This conversation stuck in my head, and I had some years to reflect on
it. There are a couple of causes at the core of this problem. The main
cause, in my opinion, is that the personality that is required to
bootstrap a project is not the best personality to make that project
grow.

## Starting vs. Growing a Project

Starting a new operating system project requires strong opinions. You
want your system to have certain properties. You are not willing to
compromise because if you are in the compromising mindset, you could
have [just used Linux](https://doc.cat-v.org/bell_labs/utah2000/utah2000.html). Linux is everything to everyone, so you could
have squinted your eyes to build your ideas on top of it. Instead, you
chose to start over because your ideas were so important to you that
you were not willing to compromise.

In this bootstrapping phase, you are typically alone or work with few
disciples that intimately share your vision. You freely implement
things your way. If you need a custom build system to fine-tune your
build flow, why not write one as well!

At some point, you reach a state where it's challenging to make
meaningful progress without external contributions to work on larger
use cases and iron out the kinks of a still-niche project. You need to
grow a community.

To grow a community, you need an entirely different skill set. The
lone hacker with a clear vision in their mind is not equipped to do
this. Instead of writing beautifully crafted code yourself, you need
to be the inspiring leader that rallies people to your cause and
establishes structures that will outlast yourself. New developers will
come with new ideas and different ways of working. Some of your
initial idiosyncratic choices have to give way, while the overall
vision remains and evolves.

The person who spent hours implementing their own build system now has
to contend with people who say there is a better tool to do the
job. And better here usually means much better for them, but worse for
you because the old system was carefully polished for your own use
case.

So now it's time to compromise. Do you insist on having this special
build system, or do you switch to something other people are familiar
with? If you keep insisting on your idiosyncrasies that are not core
to the mission of the project, you risk alienating contributors.

To summarize: The skills that you need to start a radical new project
are the skills that will not help you in growing a community.

## My Wishes

My wishes for the community are to find a way to collaborate instead
of starting all over again and again. We need to attrach users. We
need to find the "killer app", where these kinds of systems are
obviously better than Linux. And this niche cannot be just pleasing
the [BSI](https://www.bsi.bund.de/) in certifications.

Systems must be trivial to use and contribute to. We need to embrace
open source and open decision processes. No
[CLAs](https://en.wikipedia.org/wiki/Contributor_License_Agreement)!
Make it trivial to use and to contribute.

We must work together!
