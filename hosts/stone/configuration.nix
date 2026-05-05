# Stone (Desktop) - Machine-specific configuration
{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "stone";

  desktop.terminal = pkgs.ghostty;
  desktop.hasPrivateKeys = true;

  # Desktop: Direct GRUB boot (no EFI, no separate /boot partition)
  boot.loader.timeout = 0;
  boot.loader.grub = {
    enable = true;
    device = "/dev/nvme0n1";
    timeoutStyle = "hidden";
  };

  # Desktop: Disable laptop-specific services
  services.upower.enable = false;

  # Desktop: No backlight controls
  services.udev.extraRules = "";

  # NVIDIA RTX 2080 Super
  services.xserver.videoDrivers = [ "nvidia" ];
  services.xserver.deviceSection = ''
    Option "ConnectedMonitor" "DP-0, DP-4, HDMI-0"
  '';
  hardware.nvidia = {
    modesetting.enable = true;
    open = false; # Use proprietary drivers, not open kernel module
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  hardware.graphics.enable = true;
  powerManagement.cpuFreqGovernor = "performance";
}
