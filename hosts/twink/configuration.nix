# Twink (Laptop) - Machine-specific configuration
{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ../../module/bluetooth.nix
  ];

  home-manager.users.${config.identity.username}.imports = [
    ../../module/home-manager/claude.nix
  ];

  ifunnyRe.waydroidUser = config.identity.username;

  networking.hostName = "twink";

  desktop.terminal = pkgs.ghostty;
  desktop.hasPrivateKeys = true;
  desktop.hasBattery = true;
  desktop.hasBacklight = true;
  desktop.hasSpeaker = true;

  # Laptop: EFI boot with separate /boot partition
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
  };

  # Laptop: Enable battery/power management
  services.upower.enable = true;

  # Laptop: Backlight controls - allow video group to adjust brightness
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness"
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="049f", ATTRS{idProduct}=="505e", MODE="0660", GROUP="plugdev", TAG+="uaccess"
  '';

  # Hantek DSO2C10 oscilloscope: USB-TMC class device, talks SCPI via /dev/usbtmc0
  boot.kernelModules = [ "usbtmc" ];
}
