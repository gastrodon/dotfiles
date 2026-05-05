# Server - Machine-specific configuration
{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./disks.nix
  ];

  networking.hostName = "server";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.upower.enable = false;
  services.udev.extraRules = "";

  hardware.graphics.enable = true;
  powerManagement.cpuFreqGovernor = "performance";
}
