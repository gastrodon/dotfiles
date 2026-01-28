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

  # Solarized Dark
  palette = {
    black = "#073642";
    red = "#dc322f";
    green = "#859900";
    yellow = "#b58900";
    blue = "#268bd2";
    magenta = "#d33682";
    cyan = "#2aa198";
    white = "#eee8d5";

    brightBlack = "#586e75";
    brightRed = "#cb4b16";
    brightGreen = "#586e75";
    brightYellow = "#657b83";
    brightBlue = "#839496";
    brightMagenta = "#6c71c4";
    brightCyan = "#93a1a1";
    brightWhite = "#fdf6e3";

    background = "#002b36";
    foreground = "#839496";
  };

in
{
  imports = [
    ./hardware-configuration.nix
    ./module/identity.nix
    (import ./module/i3 { inherit palette local; })
    (import ./module/home-manager { inherit palette; })
    ./module/users.nix
    ./module/qdrant
    (import ./module/x11.nix { inherit palette; })
    (import "${home-manager}/nixos")
  ];

  nixpkgs.overlays = [
    (final: prev: {
      nur = import nur { pkgs = prev; };
    })
  ];

  nixpkgs.config.allowUnfree = true;

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
    ++ local.packages;

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

  services.upower.enable = true;

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness"
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
  '';

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
