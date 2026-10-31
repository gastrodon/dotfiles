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
    ../../module/claude-code.nix
    ../../module/tailscale.nix
    ../../module/tpm-client-cert.nix
  ];

  networking.hostName = "twink";

  services.tailscaleClient.enable = true;

  services.openssh.settings = {
    PermitRootLogin = "no";
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };

  services.tpmClientCert = {
    enable = true;
    token = "lab-mtls";
  };
  environment.systemPackages = [
    pkgs.sys
    pkgs.rend
  ];

  desktop.terminal = pkgs.ghostty;
  desktop.hasPrivateKeys = true;
  desktop.hasBattery = true;
  desktop.hasBacklight = true;
  desktop.hasSpeaker = true;
  desktop.idleLock = true;
  desktop.session = "wayland";
  desktop.xwayland = false;

  # EFI boot with separate /boot partition
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
  };

  services.upower.enable = true;

  # let the video group write backlight brightness
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness"
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="049f", ATTRS{idProduct}=="505e", MODE="0660", GROUP="plugdev", TAG+="uaccess"
  '';

  # Hantek DSO2C10 oscilloscope: USB-TMC class device, talks SCPI via /dev/usbtmc0
  boot.kernelModules = [ "usbtmc" ];
}
