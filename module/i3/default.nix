{ palette, local }:
{ config, pkgs, ... }:
let
  scripts = import ./scripts.nix { inherit pkgs local; };

  hostname = config.networking.hostName;

  terminalPkg = config.desktop.terminal;

  # Install i3 and essential desktop packages
  basePackages = with pkgs; [
    terminalPkg

    feh
    scrot
    imagemagick

    networkmanagerapplet
    autotiling
    xclip
    dunst
    libnotify
    polkit_gnome
    dex
    xss-lock

    iproute2
    jq
  ];

  backlightPackages = if config.desktop.hasBacklight then with pkgs; [ xbacklight ] else [ ];
  batteryPackages = if config.desktop.hasBattery then with pkgs; [ acpi ] else [ ];
  speakerPackages =
    if config.desktop.hasSpeaker then
      with pkgs;
      [
        pavucontrol
        alsa-utils
        playerctl
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

  environment.systemPackages =
    basePackages ++ backlightPackages ++ batteryPackages ++ speakerPackages ++ scripts.scripts;

  environment.variables = {
    TERMINAL = "${terminalPkg}/bin/${terminalPkg.pname}";
  };
}
