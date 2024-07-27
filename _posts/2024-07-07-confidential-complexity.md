---
layout: post
title:  "Confidential Computing: Complexity vs Security"
categories: generic
author: julian
published: true
---

This blog post is a continuation of my [previous]({% post_url
2023-02-07-intel-tdx %}) [posts]({% post_url 2023-06-28-intel-tdx-2
%}) about [Confidential
Computing](https://en.wikipedia.org/wiki/Confidential_computing).

## tl;dr

Complexity frequently leads to security issues. Adding support for a
bunch of confidential computing technologies to KVM increases its
complexity and thus softens its security stance.

## Longer Version

While scrolling through [KVM](https://linux-kvm.org/) security
vulnerabilities, it's hard not to notice an uptick of vulnerabilities
related to confidential computing, specifically [AMD
SEV](https://www.qemu.org/docs/master/system/i386/amd-memory-encryption.html). [Here](https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2021-4093)
[are](https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2022-0171)
[some](https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2023-4155)
[examples](https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2024-35791). These
vulnerabilities typically don't break the security promises of the
confidential VM, but open up issues on the host.

I have been wondering whether the enabling of confidential computing
features in KVM inadvertently lowers the security of KVM as a
whole. The confidential guest may enjoy the benefits of [some
protection]({% post_url 2023-06-28-intel-tdx-2 %}) against malicious
hypervisors, but the hypervisor has a harder time enforcing isolation
on the whole system.

KVM on x86 is already a beast through no fault of its maintainers. x86
is notoriously hard to virtualize because it is an architecture with
lots of legacy. The complexity of KVM reflects that. Also, KVM has
often been the first public implementation of many virtualization
features and thus can't enjoy the benefit of hindsight. It also has
many users, so rectifying any unfortunate API design or implementation
choice is tough because someone's problem is another person's
feature.

Given the complexities, our open-source virtualization stack would
benefit from some big corporation money and brains to simplify, harden
its security, and improve its trustworthiness. But as the incentive
structures are, CPU vendors instead have started pouring money into
developing mutually incompatible confidential computing solutions.

AMD, Intel, and ARM designed their confidential computing projects so
they can be bolted onto the existing software stack. As such, each of
these technologies adds thousands of lines of code to KVM and further increases the code base's complexity. Due to the
increased complexity, we now unsurprisingly see security issues in the
modified code.

So the technology that is supposed to help to increase trust in
virtualization has ultimately weakened the security of virtualization
for many users. Isn't this ironic?
