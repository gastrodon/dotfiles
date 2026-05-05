{ palette, local }:
{ config, pkgs, ... }:
let
  scripts = import ./scripts.nix { inherit pkgs local; };

  hostname = config.networking.hostName;

  terminalPkg = if hostname == "server" then pkgs.xterm else pkgs.ghostty;
  terminalBin = if hostname == "server" then "xterm" else "ghostty";

  # Install i3 and essential desktop packages
  basePackages = with pkgs; [
    terminalPkg

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
        xbacklight # Brightness control
        acpi # For battery status
      ]
    else
      [ ];
in
{
  # Enable i3 window manager at system level
  services.xserver.windowManager.i3 = {
    enable = true;
    package = pkgs.i3;
    extraPackages = with pkgs; [
      i3status
      i3lock
      i3blocks
    ];
  };

  environment.systemPackages = basePackages ++ laptopPackages ++ scripts.scripts;

  environment.variables = {
    TERMINAL = "${terminalPkg}/bin/${terminalBin}";
  };
}
