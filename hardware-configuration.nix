# Hardware Configuration
# This file describes the hardware configuration including disk partitioning

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Bootloader
  boot.initrd.availableKernelModules = [ "ata_piix" "ohci_pci" "ehci_pci" "ahci" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  # Filesystem configuration
  # Using entire /dev/sda disk with simple partition layout
  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/sda1";
    fsType = "ext4";
  };

  # Swap file configuration - size should match system RAM
  # After installation, create the swap file with:
  #   sudo dd if=/dev/zero of=/swapfile bs=1M count=<RAM_SIZE_IN_MB>
  #   sudo chmod 600 /swapfile
  #   sudo mkswap /swapfile
  #   sudo swapon /swapfile
  swapDevices = [
    {
      device = "/swapfile";
      size = 8192; # 8GB - adjust this to match your system's RAM size in MB
    }
  ];

  # CPU microcode updates
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  # For AMD systems, use: hardware.cpu.amd.updateMicrocode instead

  # Networking hardware
  networking.useDHCP = lib.mkDefault true;
}
