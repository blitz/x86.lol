---
layout: post
title:  "Immutable Systems: NixOS + systemd-repart + systemd-sysupdate"
categories: generic
author: julian
published: true
---

When you build software for embedded devices (your Wi-Fi router or home automation
setup on your Raspberry Pi), there is always the question how to build
these images and how to update them. What I want is:

- A mostly immutable system with few moving parts.
- A disk image that can be written to disk without a complicated installation procedure.
- A simple mechanism to securely download updates from the Internet.

There are bonus points for:

- [A/B updates](https://source.android.com/docs/core/ota/ab) with automatic rollback.
- Integrity protection for system images.

The systemd project has tooling that solves these problems:
[systemd-repart](https://www.freedesktop.org/software/systemd/man/latest/systemd-repart.html)
creates disk images during the build process and applies a partition
scheme during
boot. [systemd-sysupdate](https://www.freedesktop.org/software/systemd/man/latest/systemd-sysupdate.html)
downloads and applies system updates. They have lots of documentation,
but I couldn't find any end-to-end example.

So let's build an end-to-end example! We'll use [NixOS](https://nixos.org/), but the
high-level setup is not NixOS-specific. The final example lives
[here](https://github.com/blitz/sysupdate-playground). For the version
referenced in this blog post, check out the [`blog-post`
tag](https://github.com/blitz/sysupdate-playground/tree/blog-post).

## Partition Layout with systemd-repart

Starting from our goals above, we want the following partition
layout. We'll do this with systemd-repart offline at build time. The
sizes are somewhat arbitrary. I'm aiming for the low end here.

|------------|---------|-------------|---------------------------------------------------------------------|
| Name       | Size    | Mount Point | Description                                                         |
|------------|---------|-------------|---------------------------------------------------------------------|
| ESP        | 256 MiB | /boot       | The boot partition that holds the boot loader and Linux boot files. |
| System A   | 1 GiB   | /nix/store  | The system files.                                                   |
| System B   | 1 GiB   | /nix/store  | Alternate system files for the other installed version.             |
| Persistent | >2 GiB  | /var        | Any files that need to survive reboots.                             |
|------------|---------|-------------|---------------------------------------------------------------------|

When we build a disk image for the initial installation, the B
partition can be empty. The persistent `/var/` partition could be
created on the fly. However, in this example, we create it at
build time for simplicity.

You can see the whole partition configuration in the
[`partitions.nix`](https://github.com/blitz/sysupdate-playground/blob/blog-post/modules/partitions.nix)
module in the example. Here's a shortened version:

```nix
image.repart.partitions = {
    "esp" = {
      # The NixOS repart module let's us populate partitions easily. Here we install systemd-boot
      # and the Unified Kernel Image (UKI) of the system.
      contents = {
        "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source =
          "${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";

        "/EFI/Linux/${config.system.boot.loader.ukiFile}".source =
          "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
      };
      repartConfig = {
        Type = "esp";
        Format = "vfat";
      };
    };

    "store" = {
      # We drop all Nix store paths that we require into this partition. This includes all binaries,
      # but also everything to populate /etc.
      #
      # This is our System A partition in the table above.
      storePaths = [ config.system.build.toplevel ];
      stripNixStorePrefix = true;

      repartConfig = {
        Type = "linux-generic";
        Label = "store_${config.system.image.version}";
        Format = "squashfs";
      };
    };

    # Placeholder partition for the System B partition.
    "store-empty" = {
      repartConfig = {
        Type = "linux-generic";
        Label = "_empty";
      };
    };

    # Persistent storage
    "var" = {
      repartConfig = {
        Type = "var";
        Format = "xfs";
        Label = "nixos-persistent";

        # Wiping this gives us a clean state.
        FactoryReset = "yes";
      };
    };
  };
};
```

With this configuration, we already get a bootable image. Here we
build version 17 of our image:

```console
$ nix build .#appliance_17_image
$ ls -l result/
total 1.1G
-r--r--r-- 2 root root 1.1G Jan  1  1970 disk.qcow2
```

You can then boot this image in Qemu with the provided `qemu-efi` script
available in the development shell:

```console
$ nix develop .
$ qemu-efi ./result/disk.qcow2
[...]
<<< Welcome to ApplianceOS 24.11.20240731.9f918d6 (x86_64) - ttyS0 >>>

applianceos login: root (automatic login)

root@applianceos (version 17) $
```

So far so good!

## Building an Update Package

Now that we have our bootable image of version 17, we need a way to
update it to version 18. As stated in the beginning, we do _not_ want
to do `nixos-rebuild`, because this involves Nix evaluation and
potentially building code. We don't want to mutate our system, we want
to simply replace it with the new version.

For the update, we need two things:

- A new version of the Nix store,
- A new Linux kernel and initrd as [UKI](https://github.com/uapi-group/specifications/blob/main/specs/unified_kernel_image.md).

We already prepared our system for a second copy of the Nix store: We
have an empty partition for this. We just need a new partition image
for the Nix store. The `image.repart` module can provide individual
partition images via the following in the NixOS configuration:

```nix
image.repart.split = true;
```

We can build the UKI for our new system version via the
`config.system.build.uki` of an evaluated NixOS configuration:

```console
$ nix build .#nixosConfigurations.appliance_18.config.system.build.uki
$ ls -lh result/
total 43M
-r--r--r-- 2 root root 43M Jan  1  1970 appliance_18.efi
```

With some minor NixOS magic, we can build our update package:

```console
$ nix build .#appliance_18_update
$ ls -lh result/
total 318M
-r--r--r-- 2 root root  43M Jan  1  1970 appliance_18.efi.xz
-r--r--r-- 2 root root 276M Jan  1  1970 store_18.img.xz
```

## Configuring systemd-sysupdate

Ok, we have our update, but now we need to apply it. This is where
[systemd-sysupdate](https://www.freedesktop.org/software/systemd/man/latest/systemd-sysupdate.html)
comes in. systemd-sysupdate is a tool that scans update
_sources_ for new updates and then allows to apply them to _targets_.

Sources can be web servers for fetching files via the Internet or
local directories. Targets can be directories or partitions on the
local system.

In our example, we want to:

- Place the UKI of an update package into the right directory on the ESP,
- Place the new Nix store into an available partition.

For simplicity, we will tell systemd-sysupdate to look for updates in
`/var/updates`.  You can see the whole systemd-sysupdate
[configuration](https://www.freedesktop.org/software/systemd/man/latest/sysupdate.d.html)
in the
[`sysupdate.nix`](https://github.com/blitz/sysupdate-playground/blob/blog-post/modules/sysupdate.nix)
module in the example. Here's the shortened version:

```nix
systemd.sysupdate = {
  enable = true;

  transfers = {
     # This section describes the UKI update procedure.
    "10-uki" = {
      Source = {
        # The name pattern of compressed UKI files to download. @v is
        # a place holder for the version number.
        MatchPattern = [
          "${config.boot.uki.name}_@v.efi.xz"
        ];

        # We could fetch updates from the network as well:
        #
        # Path = "https://download.example.com/";
        # Type = "url-file";
        Path = "/var/updates/";
        Type = "regular-file";
      };

      # We want to place the uncompressed UKI into the ESP.
      Target = {
        MatchPattern = [
          "${config.boot.uki.name}_@v.efi"
        ];

        Path = "/EFI/Linux";
        PathRelativeTo = "boot";

        Type = "regular-file";
      };

      # Prevent the currently booted version from being garbage
      # collected by systemd-sysupdate.
      Transfer = {
        ProtectVersion = "%A";
      };
    };

    # This section describes the Nix store update procedure.
    "20-store" = {
      Source = {
        MatchPattern = [
          "store_@v.img.xz"
        ];

        Path = "/var/updates/";
        Type = "regular-file";
      };

      Target = {
        # The target is an available partition on this device.
        # This can in some cases be auto-detected.
        Path = "/dev/sda";

        # The target partition will have this label.
        MatchPattern = "store_@v";
        Type = "partition";
      };
    };
  };
};
```

## Applying the Update

To apply the update, boot the system image as before:

```console
$ nix build .\#appliance_17_image
$ qemu-efi ./result/disk.qcow2
[ ... ]
```

We continue in the shell in the VM. For demo convenience, the example
already has the update package for version 18 in `/var/update`:

```console
$ ls -lh /var/updates/
total 324M
-r--r--r-- 1 root root  43M Aug 11 15:47 appliance_18.efi.xz
-r--r--r-- 1 root root 276M Aug 11 15:47 store_18.img.xz
```

systemd-sysupdate finds version 18 as an update candidate:

```console
$ systemd-sysupdate
  VERSION INSTALLED AVAILABLE ASSESSMENT
↻ 18                    ✓     candidate
● 17          ✓               current
```

The update to version 18 can then be applied:

```console
$ systemd-sysupdate update
Selected update '18' for install.
Making room for 1 updates…
Removed no instances.
⤵️ Acquiring /var/updates/appliance_18.efi.xz → /boot/EFI/Linux/appliance_18.efi...
Importing '/var/updates/appliance_18.efi.xz', saving as '/boot/EFI/Linux/.#sysupdateappliance_18.efifce0abb2fdba79a5'.
[...]
Successfully acquired '/var/updates/appliance_18.efi.xz'.
⤵️ Acquiring /var/updates/store_18.img.xz → /proc/self/fd/3p2...
Importing '/var/updates/store_18.img.xz', saving at offset 269484032 in '/dev/sda'.
[...]
Successfully acquired '/var/updates/store_18.img.xz'.
Successfully installed '/var/updates/appliance_18.efi.xz' (regular-file) as '/boot/EFI/Linux/appliance_18.efi' (regular-file).
Successfully installed '/var/updates/store_18.img.xz' (regular-file) as '/proc/self/fd/3p2' (partition).
✨ Successfully installed update '18'.
```

Now you can reboot the VM. Once the system is back up, you can remove
the last version. This would also happen automatically when the next
version is installed:

```console
% systemd-sysupdate vacuum -m 1
```

## Final Words

This was a whirlwind tour through systemd-repart and
systemd-sysupdate that hopefully gave you an overview how they work. I invite you to explore the
[example](https://github.com/blitz/sysupdate-playground)!

There are lots of pieces missing in the example that I would like to add:

- Growing partitions on boot,
- Automatically creating `/var` on first boot,
- Automatic rollback on boot failures,
- Secure Boot,
- TPM-based disk encryption,
- ...

If you feel like experimenting with any of these features, please open
a PR or drop me a message. I would love to see what you did!
