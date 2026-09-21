# The diskless OptiPlex cluster node (EVA-298 / EVA-299).
#
# ONE image serves all three boxes; identity comes from the DHCP-derived
# hostname (module/cluster-node.nix). See wiki: Diskless netboot node image:
# design decisions.
#
# Imports netboot.nix, not netboot-minimal.nix (EVA-299's original spec) — see
# wiki.
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

  # The NICs actually present in the fleet: e1000e (192.168.0.58/.17), r8169
  # (192.168.0.5). Named explicitly, not via hardware.enableAllHardware — see
  # wiki: Diskless netboot node image.
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

  # r8169 firmware-blob fallback costs a link-training retry on every boot —
  # see wiki: Diskless netboot node image.
  hardware.enableRedistributableFirmware = lib.mkForce true;

  # OptiPlex 9020s only netboot in legacy BIOS mode: plain VGA text console.
  boot.kernelParams = [ "console=tty0" ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # Allowlist, not a blanket allowUnfree — see wiki: Diskless netboot node
  # image.
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "nomad" ];

  # Level 9, not 19 — see wiki: Diskless netboot node image.
  netboot.squashfsCompression = "zstd -Xcompression-level 9";

  # `system.build.netboot` (what EVA-299 specified) does not exist in
  # nixpkgs; this defines the aggregate pixiecore actually needs. See wiki:
  # Diskless netboot node image.
  #
  #   nix build .#nixosConfigurations.cluster-node.config.system.build.netbootDir
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
