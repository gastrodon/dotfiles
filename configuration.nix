# NixOS System Configuration
# Main system configuration file that imports all modules

{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./module/users.nix
    ./module/x11.nix
    ./module/i3.nix
  ];

  # Bootloader configuration
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = false;

  # Networking
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  # Time zone and locale
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  # Enable sound
  sound.enable = true;
  hardware.pulseaudio.enable = true;

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
  ];

  # Enable the OpenSSH daemon (optional, but useful for remote access)
  services.openssh.enable = true;

  # System state version - DO NOT CHANGE
  system.stateVersion = "24.05";
}
