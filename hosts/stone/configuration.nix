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
    ../../module/avahi.nix
    ../../module/nomad-client.nix
  ];

  networking.hostName = "stone";
  services.nomadClient.datacenter = "stone";

  desktop.terminal = pkgs.ghostty;
  desktop.hasPrivateKeys = true;
  desktop.hasSpeaker = true;

  desktop.extra.i3config = {
    workspaceOutputAssign = [
      { workspace = "10"; output = "DP-3"; }
    ];
    startup = [
      {
        command = "${pkgs.xorg.xrandr}/bin/xrandr --output DP-4 --auto --output DP-0 --auto --right-of DP-4 --output DP-3 --auto --above DP-0";
        notification = false;
      }
    ];
  };

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
  hardware.nvidia = {
    modesetting.enable = true;
    open = false; # Use proprietary drivers, not open kernel module
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  hardware.graphics.enable = true;
  powerManagement.cpuFreqGovernor = "performance";

  swapDevices = [
    {
      device = "/swapfile";
      size = 16 * 1024;
    }
  ];
}
