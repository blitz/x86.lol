---
layout: post
title:  "IOAPIC Mysteries: IRQ Pin Assertion Register"
categories: generic
author: julian
published: true
---

On x86, the [IOAPIC](https://wiki.osdev.org/IOAPIC) is an interrupt
controller that takes incoming interrupts from interrupt pins and
converts them to [Message Signaled Interrupts
(MSIs)](https://en.wikipedia.org/wiki/Message_Signaled_Interrupts]). If
you zoom out from the details, the IOAPIC is essentially a table that
has one MSI address/data pair for each interrupt pin that connects to
it. Simple.

Recently, I have been modernizing some IOAPIC code. [Thomas
Prescher](https://twitter.com/gonzodaruler) poked me in code review
about this feature bit of the IOAPIC that is documented in the [Intel
PCH
specification](https://www.intel.com/content/dam/www/public/us/en/documents/datasheets/9-series-chipset-pch-datasheet.pdf)
(page 412):

![PCH PRQ Feature Bit](/assets/ioapic-pch-prq.png)
{: style="text-align: center;"}

The _Pin Assertion Register_ they refer to is not documented. The
original [IOAPIC
specification](http://web.archive.org/web/20161130153145/http://download.intel.com/design/chipsets/datashts/29056601.pdf)
does not even mention this feature bit, let alone the register. What
is this register?

The first clue we found was the [Intel® 82806AA PCI 64 Hub (P64H)
specification](https://datasheet.octopart.com/FW82806AA-SL3VZ-Intel-datasheet-13695406.pdf)
(page 41) from 2001 that explained the register:

![PRQ Register Description](/assets/ioapic-prq-description.png)
{: style="text-align: center;"}

So the idea is that a _device_ writes to this IOAPIC register, which
is typically at address 0xFEC00020, to trigger a "virtual" interrupt
pin. Weird.

At this point, we were not sure what this was good for. This feature
could not be used for level-triggered interrupts, because this
interrupt delivery method only had a "interrupt now!" command instead
of assert/deassert. But asserting and deasserting would be necessary
to emulate level-triggered interrupts. If you need edge-triggered
interrupts and can do a data write, you can just send an MSI directly.

The final clue is from [this blog
post](https://blog.actorsfit.com/a?ID=01700-495cb485-b224-4789-82e8-7c0892b81a64):

> When the PCIe device needs to submit an MSI interrupt request, it
> will write the data in the Message Data register to the 0xFEC00020
> address of the PCI bus domain. At this time, this memory write
> request writes the data into The IRQ Pin Assertion Register of I/O
> APIC, and the I/O APIC will finally send this MSI interrupt request
> to the Local APIC, and then the Local APIC will pass the INTR#
> signal to the CPU. Submit an interrupt request.

😱 So the way this feature works is that PCI devices send MSI messages
to the IOAPIC to trigger a virtual interrupt pin. The IOAPIC then
checks its table entry for this virtual pin and sends an actual MSI to
the LAPIC. [What is even going
on?](https://www.danielbozhkovart.com/darth-vader)

We have questions:

- Has anyone seen an IOAPIC that actually supports the _IRQ Pin
  Assertion Register_? Please tell us!
- What happens if you use the register for virtual interrupt pin that
  is configured as level-triggered in the IOAPIC?
- Why was this ever useful on x86 given that it requires both a
  MSI-capable PCI device _and_ a Local APIC, which receives MSIs
  directly?

If you have information, please share it with us via Twitter or email
(see below). We are confused.
