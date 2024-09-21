---
layout: post
title:  "Immutable Systems: Cross-Compiling for RISC-V using Nix Flakes"
categories: generic
author: julian
published: true
---

In my [last post]({% post_url 2024-08-28-systemd-sysupdate %}), we
built whole disk images for embedded systems using
[Nix](https://nixos.org). This approach is well suited for RISC-V or
ARM systems, but you probably don't have a powerful build box for
this architecture. You wouldn't want to build a Linux kernel for hours
on a [RISC-V single-board
computer](https://linux-sunxi.org/Allwinner_Nezha) praying that you
don't run out of RAM...

In this blog post, we will use the _same NixOS configuration_ to
_cross-compile_ system images for _x86_, _RISC-V_ and _ARM_ from our
powerful x86 build server.

Let's go over some theory first and then look at how this applies to
our flake from [the previous post]({% post_url 2024-08-28-systemd-sysupdate %}). A complete example lives in
[here](https://github.com/blitz/sysupdate-playground). For the version
that was current when this blog post was written, check out the
[`blog-post-2`
tag](https://github.com/blitz/sysupdate-playground/tree/blog-post-2).

## Cross-Compiling NixOS

[nixpkgs](https://nixos.org/manual/nixpkgs/stable/) has excellent [cross-compilation
support](https://nixos.org/manual/nixpkgs/stable/#chap-cross). There
are also excellent resources for cross-compiling individual
packages. Cross-compiling _whole systems_ is even easier, but not as
well documented. There are two main ways to configure it. For a deeper
discussion, check out [this
post](https://discourse.nixos.org/t/recommended-style-to-cross-compile-flake-nixossystems/45305).

### Approach 1: nixpkgs.buildPlatform/hostPlatform

The first approach is to configure the build and host system in the
NixOS configuration. The terminology that NixOS uses is:

- [`buildPlatform`](https://search.nixos.org/options?channel=unstable&show=nixpkgs.buildPlatform&from=0&size=50&sort=relevance&type=packages&query=buildPlatform)
  for configuring what kind of system does the actual build,
- [`hostPlatform`](https://search.nixos.org/options?channel=unstable&show=nixpkgs.hostPlatform&from=0&size=50&sort=relevance&type=packages&query=hostPlatform)
  for configuring what kind of system the resulting binaries should
  run on.

For me, the name `hostPlatform` is somewhat ambiguous, but these are the names
we are stuck with.

To configure a NixOS configuration for cross compiling, you can use a
module like this:

```nix
{ ... }: {
  nixpkgs.buildPlatform = "x86_64-linux";
  nixpkgs.hostPlatform = "riscv64-linux";
}
```

### Approach 2: Build `pkgs` Yourself

The second approach is to build a cross-compiling `pkgs` set yourself
and then just use this for your NixOS configuration. Assuming
`nixpkgs` is the nixpkgs flake input, you can create it like this:

```nix
let
  # Let's stick to the terminology from earlier.
  buildPlatform = "x86_64-linux";
  hostPlatform = "riscv64-linux";

  crossPkgs = import nixpkgs { localSystem = buildPlatform; crossSystem = hostPlatform; }

  # ...
```

As you can see, we re-evaluate nixpkgs with parameters that enable
cross-compilation. The challenge is mostly the changed terminology
🫠. `localSystem` is the system to build on and `crossSystem` is the
system where the final system needs to run.

The resulting `crossPkgs` can then be used to configure
cross-compilation in the NixOS configuration:

```nix
{ ... }: {
  nixpkgs.pkgs = crossPkgs;
}
```

You cannot mix these approaches. If you set `nixpkgs.pkgs`,
`buildPlatform` and `hostPlatform` will be _ignored_.

## Flakes and Cross-Compilation

To always cross-compile from your local system, you can set
`buildPlatform` to `builtins.currentSystem`. This doesn't work with
flakes, because they don't allow you to call
`builtins.currentSystem`. It would leak details of the build platform
into the flake outputs. The flake would not be fully encapsulated and thus
impure. This is one reason why flakes have a bad reputation when it
comes to cross-compilation.

Despite the misgivings, cross-compiling with flakes actually works
great. It's just that the flake has to be _prepared_ for
cross-compilation. Let's go through that for the immutable appliance
example.

When I wrote the example, I aimed for the following outputs for the
flake:

```
packages
├───riscv64-linux             # Cross-compiled
│   ├───appliance_17_image
│   ├───appliance_17_update
│   ├───appliance_18_image
│   └───appliance_18_update
└───aarch64-linux             # Cross-compiled
│   └ ...
└───x86_64-linux
    ├───appliance_17_image
    ├───appliance_17_update
    ├───appliance_18_image
    └───appliance_18_update
```

As you see, each version of our example appliance produces one install
disk image and one update package for systemd-sysupdate (see the [last
post]({% post_url 2024-08-28-systemd-sysupdate %}) for how this is
used).

To build all these images from x86, we only need to apply our
theoretical knowledge from above to define `crossNixos` as a
convenience wrapper to add the cross-compilation module to an existing
NixOS configuration:

```nix
  outputs = { self, nixpkgs, flake-utils, ... }:
    let
      # The platform we want to build on. This should ideally be configurable.
      buildPlatform = "x86_64-linux";
    in
    (flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux"
                                  "riscv64-linux" ]
      (system:
        let
          # We treat everything as cross-compilation without a special
          # case for the build platform. Nixpkgs will do the right thing.
          crossPkgs = import "${nixpkgs}" { localSystem = buildPlatform;
                                            crossSystem = system; };

        # A convenience wrapper around lib.nixosSystem that configures
        # cross-compilation.
        crossNixos = module: nixpkgs.lib.nixosSystem {
          modules = [
            module

            {
              nixpkgs.pkgs = crossPkgs;
            }
          ];
        };

      in {
        # ...
```

With this out of the way, we can then define a NixOS configuration
that is cross-compiled for all our target architectures like this:

```nix
        appliance_18 = crossNixos {
          imports = [
            ./base.nix
            ./version-18.nix
          ];
        }
```

Note that we can use _the same configuration_ to generate system
images for x86, RISC-V and ARM and we build all of them on our beefy
x86 build boxes! 🤯

It's a nice exercise to make the build platform configurable. I leave
this as an exercise to the reader. Check out
[nix-systems](https://github.com/nix-systems/nix-systems) as a
starting point.

## Running the Images

If you are in the development shell, you can run the cross-compiled images
in Qemu:

```shell
# uname -m
x86_64

# Enter the development shell that provides the qemu-efi convenience tool.
$ nix develop

# Build the disk image for version 17 of the appliance.
$ nix -L build .\#packages.riscv64-linux.appliance_17_image

$ qemu-efi riscv64 result/disk.qcow2
...
<<< Welcome to ApplianceOS 24.11.20240906.574d1ea (riscv64) - ttyS0 >>>


applianceos login: root (automatic login)

root@applianceos (version 17) $ uname -a
Linux applianceos 6.6.49 #1-NixOS SMP Wed Sep  4 11:28:31 UTC 2024 riscv64 GNU/Linux
```

## Parting Words

If you have comments or suggestions about this style of
cross-compilation with Nix, please reach out. I'm eager to hear them!
