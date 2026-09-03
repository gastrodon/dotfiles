{
  config,
  lib,
  pkgs,
  obsidian-local-rest-api,
  claude-code-nix,
  pi-voice,
  ...
}:
let
  local = import ../package { inherit pkgs lib; };
  clusterHosts = import ../module/hosts.nix;

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
    ../module/terminal.nix
    ../module/identity.nix
    (import ../module/i3 { inherit palette local; })
    (import ../module/home-manager {
      inherit
        palette
        obsidian-local-rest-api
        claude-code-nix
        pi-voice
        ;
    })
    ../module/steam
    ../module/users.nix
    (import ../module/x11.nix { inherit palette; })
    ../module/podman.nix
    ../module/sops.nix
  ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.sandbox = "relaxed";
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  networking.networkmanager.enable = true;
  networking.extraHosts = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: ip: "${ip} ${name}") clusterHosts
  );
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  environment.systemPackages =
    with pkgs;
    [
      vim
      curl
      git
      xdotool
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

  programs.nix-ld.enable = true;

  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "armv7l-linux"
  ];

  # Cap rollback history to the last N system generations. Without this, every
  # `nixos-rebuild switch` pins its whole closure alive forever (gc roots the
  # profile generation), and /nix/store grows unbounded across NixOS version
  # bumps in particular. This trims both the GRUB boot menu and the actual
  # profile + store on disk, so `nixos-rebuild switch --rollback` (or picking
  # an older entry at boot) still works for the last N, and older ones get
  # reclaimed automatically.
  boot.loader.grub.configurationLimit = 10;

  nix.gc = {
    automatic = true;
    dates = "daily";
    persistent = true;
  };

  systemd.services.trim-system-generations = {
    description = "Keep only the last N NixOS system generations";
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.nix}/bin/nix-env -p /nix/var/nix/profiles/system --delete-generations +${toString config.boot.loader.grub.configurationLimit}
    '';
  };

  systemd.timers.trim-system-generations = {
    description = "Daily system generation trim";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };

  # Run after the trim so the same daily pass both drops old generations and
  # reclaims the store paths that were only kept alive by them.
  systemd.services.nix-gc = {
    after = [ "trim-system-generations.service" ];
    requires = [ "trim-system-generations.service" ];
  };

  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  system.stateVersion = "25.11"; # DO NOT CHANGE
}
