---
layout: post
title:  "Lanzaboote: Towards Secure Boot for NixOS"
categories: generic
author: julian
published: true
---

[Secure Boot](https://en.wikipedia.org/wiki/UEFI#Secure_Boot) protects
a system from an attacker that compromises the boot flow. For example,
without Secure Boot it is easy to replace the code that reads your
disk encryption password and store it somewhere where the attacker can
pick it up later. So ideally you want Secure Boot to be enabled to
limit the code that runs on your system to what is supposed to run
there.

Unfortunately, [NixOS](https://nixos.org), the Linux distro I use as a
daily driver, does not have Secure Boot support. Something had to be
done. On an island. 🌴

![](/assets/2022-11-oceansprint.webp)

While attending the [Ocean Sprint](https://oceansprint.org/), a
Nix-focussed hackathon, I chose to team up with
[nikstur](https://github.com/nikstur) and
[raitobezarius](https://github.com/RaitoBezarius) to work on Secure
Boot for NixOS!

The sprint was an amazing opportunity to network with seasoned Nix
veterans and also great fun in general. Many thanks to zupo and Domen
for organising it!

# Secure Boot with systemd-boot

Maybe some background first. As other distros, NixOS boots via
[systemd-boot](https://www.freedesktop.org/wiki/Software/systemd/systemd-boot/)
on UEFI systems. For Secure Boot to work, systemd-boot demands
[UKIs](https://wiki.archlinux.org/title/Unified_kernel_image). UKI is
a format that is intended to wrap a Linux kernel, its command line and
the initrd into a EFI application. This EFI application is then
signed.

For UKI, the boot flow looks like this.

1. UEFI verifies and loads sytemd-boot.
2. systemd-boot looks for UKIs and the user can select one to boot.
3. systemd-boot loads and starts the UKI.
4. The UKI boots the Linux kernel and intrd that it finds embedded in
   itself.

The chain of trust of Secure Boot is maintained by UEFI. All
components use
[`LoadImage`](https://uefi.org/specs/UEFI/2.10/07_Services_Boot_Services.html#efi-boot-services-loadimage)
to load files and `LoadImage` verifies the embedded signatures.

It's an elegant design that avoids duplicating crypto in the boot
loader and shoves all of this to UEFI.

# NixOS-specific Problems and Solutions

NixOS users tend to have many [system
generations](https://nixos.wiki/wiki/Overview_of_the_NixOS_Linux_distribution#Generations)
lying around. Each of those needs to have a boot loader entry. In the
"traditional" UKI flow described above, this would mean a fat UKI
binary, including kernel and initrd that may not even have changed,
for every generation. Your
[ESP](https://en.wikipedia.org/wiki/EFI_system_partition) would
quickly fill up.

For NixOS, we wanted to retain the ability to store Linux kernel and
initrd separately from the UKI. This means we needed to develop our
own stub.

# Lanzaboote: A EFI UKI Stub for NixOS

To solve the above problem, we developed a small UEFI application
(lanzaboote) that conforms to the UKI spec _without_ embedding kernel
and initrd into the UKI itself. Instead we only embed path names and
defer signature checking to UEFI with `LoadImage`.

Lanzaboote is developed in Rust. Because the `x86_64-unknown-uefi`
target is now a [Tier
2](https://www.phoronix.com/news/Rust-UEFI-Promoted-Tier-2), the
development environment is nice. No need for
[`build-std`](https://doc.rust-lang.org/nightly/cargo/reference/unstable.html#build-std)
anymore. I also want to highlight the
[rust-osdev/uefi-rs](https://github.com/rust-osdev/uefi-rs)
project. It helps enourmously to take the hassle out of dealing with
UEFI.

# Integration in Nixpkgs

The biggest blob of work is integrating this all into NixOS and
nixpkgs. This is where [nikstur](https://github.com/nikstur) and
[raitobezarius](https://github.com/RaitoBezarius) lead the effort.

We now have lanzatool for assembling the UKI, signing binaries and
populating the ESP. We also have the NixOS modules to install
everything during `nixos-rebuild switch`.

And of course we have integration tests. 👍

# Root of Trust

So far we do not have a way to establish a chain of trust from the
(Microsoft) keys that your laptop trusts by default. This means the
user has to generate their own keys, which is a bit of an
[intimidating
process](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot#Creating_keys). These
keys then also have to be enrolled in the firmware.

We plan on streamlining this as much as possible, but so far this has
not happened yet.

# Get Involved

These are still early days and quite a bit has to happen before Secure
Boot for NixOS can be upstreamed. The current status can be found by
reading [lanzaboote README](https://github.com/blitz/lanzaboote). If
you want to help out, please join us on
[#nixos-secure-boot:ukvly.org](https://matrix.to/#/#nixos-secure-boot:ukvly.org).

I'll leave you with this screenshot of the GNOME Device Security tab:

![](/assets/2022-11-gnome-device-sec.png)

If someone knows, what's up with the question mark, please comment on
[this](https://github.com/fwupd/fwupd/issues/5284) issue.
