{
  config,
  lib,
  pkgs,
  ...
}:
let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-25.11.tar.gz";
  nur = builtins.fetchTarball "https://github.com/nix-community/NUR/archive/master.tar.gz";
  local = import ./package { inherit pkgs lib; };
in
{
  imports = [
    ./hardware-configuration.nix
    ./module/identity.nix
    ./module/i3
    ./module/home-manager
    ./module/users.nix
    ./module/x11.nix
    (import "${home-manager}/nixos")
  ];

  nixpkgs.overlays = [
    (final: prev: {
      nur = import nur { pkgs = prev; };
    })
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

  # https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages =
    with pkgs;
    [
      vim
      curl
      git
    ]
    ++ local.pkgs;

  fonts.packages = with pkgs; [
    fira-code
    fira-code-symbols
    font-awesome
    noto-fonts
    (iosevka-bin.override { variant = "SS04"; })
  ];

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  systemd.user.services.polkit-gnome = {
    description = "Polkit GNOME Authentication Agent";
    wantedBy = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };

  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  system.stateVersion = "25.11"; # DO NOT CHANGE
}
