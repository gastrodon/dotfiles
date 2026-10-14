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
lib.mkIf (desktop.session == "x11") {
  xsession.windowManager.i3 = {
    enable = true;
    package = pkgs.i3;

    config = lib.mkMerge [
      common.config
      {
        keybindings = lib.mkOptionDefault {
          "${mod}+Shift+r" = "restart";

          "Print" =
            "exec --no-startup-id ${pkgs.scrot}/bin/scrot ~/Pictures/scrot/%Y-%m-%d-%T.png && ${pkgs.libnotify}/bin/notify-send \"Screenshot saved\" \"~/Pictures/scrot/$(${pkgs.coreutils}/bin/date +\"%Y-%m-%d-%T\").png\"";
        };

        startup = [
          {
            command = "${pkgs.autotiling}/bin/autotiling";
            notification = false;
          }
          {
            command = "${pkgs.dex}/bin/dex --autostart --environment i3";
            notification = false;
          }
          {
            command = "${pkgs.dunst}/bin/dunst";
            notification = false;
          }
          {
            command = "${pkgs.feh}/bin/feh --bg-tile ${wallpaper}/wall.jpg";
            notification = false;
          }
          {
            command = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
            notification = false;
          }
          {
            command = "${pkgs.xset}/bin/xset s off -dpms";
            notification = false;
          }
          {
            command = "${pkgs.xss-lock}/bin/xss-lock -l blur-lock";
            notification = false;
          }
        ];
      }
      desktop.extra.i3config
    ];
  };
}
