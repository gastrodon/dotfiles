{ palette }:
{ config, pkgs, ... }:
let
  scripts = import ./scripts.nix { inherit pkgs; };
  blocks = import ./blocks.nix { inherit pkgs; };

  wallpaper =
    pkgs.runCommand "wallpaper-scaled"
      {
        buildInputs = [ pkgs.imagemagick ];
      }
      ''
        mkdir -p $out
        convert ${./wall.jpg} -resize 50% $out/wall.jpg
      '';

  i3config = import ./config {
    inherit pkgs palette;
    username = config.identity.username;
    wallpaper = "${wallpaper}/wall.jpg";
  };
in
{
  services.xserver.windowManager.i3 = {
    enable = true;
    package = pkgs.i3;
    extraPackages = with pkgs; [
      i3status
      i3lock
      i3blocks
    ];
  };

  # Install i3 and essential desktop packages
  environment.systemPackages =
    with pkgs;
    [
      ghostty # terminal emulator

      feh # Wallpaper setter
      scrot # Screenshot utility
      imagemagick # For blur effects in lock script

      pavucontrol # Volume control GUI
      networkmanagerapplet # NetworkManager system tray applet
      xorg.xbacklight # Brightness control

      autotiling # switches tiling directions
      xclip # clipboard
      dunst # notifier
      libnotify # notification daemon
      playerctl # media control
      polkit_gnome # gui authenticator
      dex # xdg-open
      xss-lock # screen locker

      acpi # For battery status
      iproute2 # For network interface info
      alsa-utils # For amixer volume control
    ]
    ++ scripts.scripts
    ++ blocks.scripts;

  # Write i3 config files to user's home directory
  systemd.tmpfiles.rules = [
    "d /home/${config.identity.username}/.config/i3 0755 ${config.identity.username} users - -"
    "f /home/${config.identity.username}/.config/i3/config 0644 ${config.identity.username} users - -"
    "f /home/${config.identity.username}/.config/i3/i3blocks.conf 0644 ${config.identity.username} users - -"
  ];

  environment.etc."i3-config-source".text = i3config.config;
  environment.etc."i3blocks-config-source".text = blocks.config;

  system.activationScripts.i3config = ''
    cp \
      ${config.environment.etc."i3-config-source".source} \
      /home/${config.identity.username}/.config/i3/config

    cp \
      ${config.environment.etc."i3blocks-config-source".source} \
      /home/${config.identity.username}/.config/i3/i3blocks.conf

    chown \
      ${config.identity.username}:users \
      /home/${config.identity.username}/.config/i3/config \
      /home/${config.identity.username}/.config/i3/i3blocks.conf
  '';

  environment.variables = {
    TERMINAL = "${pkgs.ghostty}/bin/ghostty";
  };
}
