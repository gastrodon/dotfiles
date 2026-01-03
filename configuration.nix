{
  config,
  lib,
  pkgs,
  ...
}:
let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-25.11.tar.gz";
in
{
  imports = [
    ./hardware-configuration.nix
    ./module/i3
    ./module/home-manager
    ./module/users.nix
    ./module/x11.nix
    (import "${home-manager}/nixos")
  ];

  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
  };

  networking.hostName = "twink";
  networking.networkmanager.enable = true;
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  programs.firefox.enable = true;

  # https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    vim
    curl
    git
  ];

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  system.stateVersion = "25.11"; # DO NOT CHANGE
}
