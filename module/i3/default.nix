{ palette, local }:
{ config, pkgs, ... }:
let
  scripts = import ./scripts.nix { inherit pkgs local; };
  blocks = import ./blocks.nix { inherit pkgs config; };

  wallpaper =
    pkgs.runCommand "wallpaper-scaled"
      {
        buildInputs = [ pkgs.imagemagick ];
      }
      ''
        mkdir -p $out
        convert ${./wall.jpg} -resize 50% $out/wall.jpg
      '';

  hostname = config.networking.hostName;

  i3config = import ./config {
    inherit
      pkgs
      palette
      local
      scripts
      hostname
      ;
    username = config.identity.username;
    wallpaper = "${wallpaper}/wall.jpg";
  };

  # Install i3 and essential desktop packages
  basePackages = with pkgs; [
    ghostty # terminal emulator

    feh # Wallpaper setter
    scrot # Screenshot utility
    imagemagick # For blur effects in lock script

    pavucontrol # Volume control GUI
    networkmanagerapplet # NetworkManager system tray applet

    autotiling # switches tiling directions
    xclip # clipboard
    dunst # notifier
    libnotify # notification daemon
    playerctl # media control
    polkit_gnome # gui authenticator
    dex # xdg-open
    xss-lock # screen locker

    iproute2 # For network interface info
    alsa-utils # For amixer volume control
    jq # JSON processor for i3blocks
  ];

  # Laptop-only packages (brightness and battery)
  laptopPackages =
    if hostname == "twink" then
      with pkgs;
      [
        xorg.xbacklight # Brightness control
        acpi # For battery status
      ]
    else
      [ ];
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

  environment.systemPackages = basePackages ++ laptopPackages ++ scripts.scripts ++ blocks.scripts;

  # Write i3 config files to user's home directory
  # Note: i3blocks.conf is now managed by Home Manager (see module/home-manager/i3blocks.nix)
  systemd.tmpfiles.rules = [
    "d /home/${config.identity.username}/.config/i3 0755 ${config.identity.username} users - -"
    "f /home/${config.identity.username}/.config/i3/config 0644 ${config.identity.username} users - -"
  ];

  environment.etc."i3-config-source".text = i3config.config;

  system.activationScripts.i3config = ''
    cp \
      ${config.environment.etc."i3-config-source".source} \
      /home/${config.identity.username}/.config/i3/config

    chown \
      ${config.identity.username}:users \
      /home/${config.identity.username}/.config/i3/config
  '';

  environment.variables = {
    TERMINAL = "${pkgs.ghostty}/bin/ghostty";
  };
}
