# NixOS System Configuration
# Main system configuration file that imports all modules

{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./module/users.nix
    ./module/x11.nix
    ./module/i3.nix
    ./module/firefox.nix
  ];

  # Bootloader configuration
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = false;

  # Networking
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  
  # WiFi Networks Configuration
  # Add your WiFi networks here. You can configure multiple networks.
  # After adding networks, run: sudo nixos-rebuild switch
  # 
  # Example configuration:
  # networking.networkmanager.ensureProfiles.profiles = {
  #   "MyHomeWiFi" = {
  #     connection = {
  #       id = "MyHomeWiFi";
  #       type = "wifi";
  #     };
  #     wifi = {
  #       ssid = "MyHomeWiFi";
  #       mode = "infrastructure";
  #     };
  #     wifi-security = {
  #       key-mgmt = "wpa-psk";
  #       psk = "your-wifi-password-here";
  #     };
  #     ipv4.method = "auto";
  #     ipv6.method = "auto";
  #   };
  #   "WorkWiFi" = {
  #     connection = {
  #       id = "WorkWiFi";
  #       type = "wifi";
  #     };
  #     wifi = {
  #       ssid = "WorkWiFi";
  #       mode = "infrastructure";
  #     };
  #     wifi-security = {
  #       key-mgmt = "wpa-psk";
  #       psk = "work-wifi-password";
  #     };
  #     ipv4.method = "auto";
  #     ipv6.method = "auto";
  #   };
  # };
  #
  # Alternative: Use nmcli or NetworkManager GUI to configure WiFi
  # After boot, you can run: nmcli device wifi connect "SSID" password "PASSWORD"

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
