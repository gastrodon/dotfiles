# The diskless OptiPlex cluster node (EVA-298 / EVA-299).
#
# ONE image serves all three boxes. Nothing here names a machine: identity
# comes from the DHCP-derived hostname (module/cluster-node.nix), so the same
# bytes booted on any box produce a correctly-named Nomad server. That is the
# property that makes "reboot = clean slate" safe — a node coming back is the
# same node, not a new one accumulating in the Raft peer set.
#
# ON THE IMPORTS: EVA-299 says to import
# `(modulesPath + "/installer/netboot/netboot-minimal.nix")`. This imports
# `netboot.nix` directly instead, deliberately. netboot-minimal pulls in
# netboot-base → `profiles/installation-device.nix`, which builds an *installer*
# persona: an autologin `nixos` user with an empty password, the NixOS manual,
# nixos-install/nixos-generate-config, wpa_supplicant, and a "welcome to the
# installer" MOTD. That is correct for media whose job is to install an OS and
# wrong for a node whose job is to run the cluster for months — it is both
# needless RAM and a passwordless root console on a machine that stays up.
# `netboot.nix` alone is the part EVA-299 actually wants: the squashfs store,
# the tmpfs overlay, the initrd, and the iPXE script.
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/netboot/netboot.nix")
    (modulesPath + "/profiles/minimal.nix")
    ../../module/cluster-node.nix
  ];

  services.clusterNode.diskless = true;

  # The NICs actually present in the fleet, both in the initrd so the booted
  # system has a link no matter which box the image lands on:
  #   e1000e — Intel, eno1 on 192.168.0.58 and 192.168.0.17
  #   r8169  — Realtek, enp3s0 on 192.168.0.5
  # Named explicitly rather than via `hardware.enableAllHardware`, which is
  # what netboot-base would have set: that pulls the whole firmware tree into a
  # closure that has to fit in 7.7 GiB of RAM alongside the workloads.
  boot.initrd.availableKernelModules = [
    "e1000e"
    "r8169"
    "ahci"
    "sd_mod"
    "usb_storage"
    "usbhid"
    "xhci_pci"
    "ehci_pci"
  ];

  # r8169 asks the firmware loader for a blob on several Realtek variants and
  # falls back to a built-in path when it is absent — but the fallback costs a
  # link-training retry on every boot, and this is the box that PXE boots.
  hardware.enableRedistributableFirmware = lib.mkForce true;

  # The OptiPlex 9020s only netboot in legacy BIOS mode, so the console is a
  # plain VGA text console; no framebuffer to configure.
  boot.kernelParams = [ "console=tty0" ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # Nomad is BSL-1.1, so it needs an unfree allowance that hosts/shared.nix
  # used to grant blanket-wide. A predicate rather than
  # `nixpkgs.config.allowUnfree = true`: this image is the whole operating
  # system of three machines and is served to anything that PXE boots, so
  # "which non-free things are in it" should be a list someone can read, not a
  # door left open. Adding a package here should be a visible decision.
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "nomad" ];

  # zstd -19 on an 18 GiB store was the slow part of iterating on this. The
  # image is fetched once per boot over a gigabit LAN, not over the internet,
  # so the last few percent of compression buys nothing and costs minutes of
  # build time on every change. Level 9 is roughly a second of decompression
  # difference at boot.
  netboot.squashfsCompression = "zstd -Xcompression-level 9";

  # EVA-299 asks for `nix build .#nixosConfigurations.cluster-node.config.system.build.netboot`.
  # THAT ATTRIBUTE DOES NOT EXIST in nixpkgs — netboot.nix defines
  # `netbootRamdisk`, `netbootIpxeScript`, `kernel` and `kexecTree`, but no
  # aggregate `netboot`. Rather than make the ticket's command wrong forever,
  # define the aggregate it was reaching for, under a name that says what it
  # is. Everything pixiecore needs lands in one store path with the filenames
  # the iPXE script already references:
  #
  #   nix build .#nixosConfigurations.cluster-node.config.system.build.netbootDir
  #
  # `cmdline` is written out alongside the artifacts on purpose. The kernel
  # command line embeds `init=/nix/store/<hash>-nixos-system.../init`, which
  # changes on every rebuild — so a deploy that had to edit the pixiecore job's
  # arguments would need a job update for every image change. Staging the
  # cmdline as a file lets the boot server read it at request time and makes a
  # redeploy "restage the directory", not "edit and resubmit a jobspec".
  system.build.netbootDir = pkgs.linkFarm "cluster-node-netboot" [
    {
      name = "bzImage";
      path = "${config.system.build.kernel}/${config.system.boot.loader.kernelFile}";
    }
    {
      name = "initrd";
      path = "${config.system.build.netbootRamdisk}/initrd";
    }
    {
      name = "netboot.ipxe";
      path = "${config.system.build.netbootIpxeScript}/netboot.ipxe";
    }
    {
      name = "cmdline";
      path = pkgs.writeText "cmdline" (
        "init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams}"
      );
    }
  ];
}
