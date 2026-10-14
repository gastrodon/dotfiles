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
  ];

  networking.hostName = "twink";

  services.openssh.settings = {
    PermitRootLogin = "no";
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };

  home-manager.users.${config.identity.username}.imports = [ ../../module/home-manager/lab-mtls.nix ];

  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
    tctiEnvironment.enable = true;
  };
  users.users.${config.identity.username}.extraGroups = [ config.security.tpm2.tssGroup ];
  environment.systemPackages = [ pkgs.tpm2-tools ];

  # the token PIN is typed into eva-uid prompts; same-uid ptrace would read it
  boot.kernel.sysctl."kernel.yama.ptrace_scope" = lib.mkDefault 1;
  assertions = [
    {
      assertion = config.boot.kernel.sysctl."kernel.yama.ptrace_scope" >= 1;
      message = "twink needs kernel.yama.ptrace_scope >= 1 for the lab-mtls PIN";
    }
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
