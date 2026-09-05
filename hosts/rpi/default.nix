{ config, pkgs, ... }:
let
  githubKeys = builtins.fetchurl {
    url = "https://github.com/gastrodon.keys";
    sha256 = "sha256-o46IPXKvUzgoNgSdLt9j3ThkeJbc6P5HGcFZKHH3Rhw=";
  };
in
{
  imports = [
    ../../module/identity.nix
    ../../module/users.nix
    ../../module/podman.nix
    ../../module/avahi.nix
    ../../module/nomad-client.nix
    ../../module/cluster-net.nix
    ../../module/sops.nix
    ../../module/tailscale.nix
  ];

  # Reach the pi directly over the tailnet instead of hopping through a
  # LAN-only box — see module/tailscale.nix. The claude age key that decrypts
  # secrets.claude.yaml still needs planting via `./bootstrap <hostname> <ip>`
  # before the first switch that turns this on.
  services.tailscaleClient.enable = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "old";

    users.${config.identity.username} = {
      imports = [ ../../module/home-manager/zsh ];
      home.stateVersion = "25.11";
      programs.home-manager.enable = true;
    };
  };

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

  # Root pubkey login for `nixos-rebuild switch --target-host root@<pi>`.
  users.users.root.openssh.authorizedKeys.keyFiles = [ githubKeys ];

  zramSwap.enable = true;
  boot.tmp.cleanOnBoot = true;

  networking.firewall.allowedTCPPorts = [ 22 ];

  system.stateVersion = "25.11";
}
