args@{
  desktop,
  pkgs,
  lib,
  ...
}:

let
  common = import ./wm-common.nix args;
  inherit (common) mod wallpaper;
in
lib.mkIf (desktop.session == "wayland") {
  home.pointerCursor = {
    package = pkgs.vanilla-dmz;
    name = "Vanilla-DMZ";
    size = 18;
    gtk.enable = true;
    x11.enable = true;
  };

  # dex would otherwise start a second nm-applet without --indicator
  xdg.configFile."autostart/nm-applet.desktop".source =
    (pkgs.formats.ini { }).generate "nm-applet.desktop"
      {
        "Desktop Entry".Hidden = true;
      };

  wayland.windowManager.sway = {
    enable = true;
    package = null;
    xwayland = desktop.xwayland;
    systemd.enable = true;

    config = lib.mkMerge [
      common.config
      {
        input."type:keyboard".xkb_layout = "us";

        output."*".bg = "${wallpaper}/wall.jpg tile";

        seat."*".xcursor_theme = "Vanilla-DMZ 18";

        floating.criteria = [
          { app_id = "org.pulseaudio.pavucontrol"; }
        ];

        keybindings = lib.mkOptionDefault {
          "Print" =
            "exec --no-startup-id f=~/Pictures/scrot/$(${pkgs.coreutils}/bin/date +%Y-%m-%d-%T).png && ${pkgs.grim}/bin/grim \"$f\" && ${pkgs.libnotify}/bin/notify-send \"Screenshot saved\" \"$f\"";
          "${mod}+b" = null;
          "${mod}+Shift+h" = null;
        };

        startup = [
          { command = "${pkgs.autotiling}/bin/autotiling"; }
          { command = "${pkgs.dex}/bin/dex --autostart --environment sway"; }
          { command = "${pkgs.dunst}/bin/dunst"; }
          { command = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"; }
          { command = "${pkgs.networkmanagerapplet}/bin/nm-applet --indicator"; }
          {
            command = "${pkgs.swayidle}/bin/swayidle -w ${lib.optionalString desktop.idleLock "timeout 300 blur-lock "}before-sleep blur-lock lock blur-lock";
          }
        ];
      }
      desktop.extra.swayconfig
    ];
  };
}
