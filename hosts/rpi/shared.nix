{ pkgs, ... }:
{
  imports = [
    ../../module/identity.nix
    ../../module/users.nix
    ../../module/podman.nix
    ../../module/avahi.nix
    ../../module/nomad-client.nix
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  networking.networkmanager.enable = false;
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  environment.systemPackages = with pkgs; [
    vim
    curl
    git
    htop
    wget
  ];

  services.openssh.enable = true;
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };

  zramSwap.enable = true;
  boot.tmp.cleanOnBoot = true;

  networking.firewall.allowedTCPPorts = [ 22 ];

  system.stateVersion = "25.11";
}
