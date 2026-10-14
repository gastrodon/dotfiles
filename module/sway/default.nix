{
  config,
  lib,
  pkgs,
  ...
}:
let
  scripts = import ../i3/scripts.nix {
    inherit pkgs;
    session = "wayland";
  };

  terminalPkg = config.desktop.terminal;

  basePackages = with pkgs; [
    terminalPkg

    grim
    imagemagick
    wl-clipboard

    networkmanagerapplet
    autotiling
    dunst
    libnotify
    polkit_gnome
    dex
    swayidle
    swaylock

    iproute2
    jq
  ];

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
  config = lib.mkIf (config.desktop.session == "wayland") {
    programs.sway = {
      enable = true;
      wrapperFeatures.gtk = true;
      xwayland.enable = config.desktop.xwayland;
      extraPackages = [ pkgs.i3blocks ];
    };

    xdg.portal.wlr.settings.screencast = {
      chooser_type = "simple";
      chooser_cmd = "${pkgs.slurp}/bin/slurp -f %o -or";
    };

    security.pam.services.swaylock = { };

    services.greetd = {
      enable = true;
      settings.default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd sway";
        user = "greeter";
      };
    };

    environment.systemPackages = basePackages ++ batteryPackages ++ speakerPackages ++ scripts.scripts;

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      MOZ_ENABLE_WAYLAND = "1";
    };

    environment.variables = {
      TERMINAL = "${terminalPkg}/bin/${terminalPkg.pname}";
    };
  };
}
