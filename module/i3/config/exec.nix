{
  pkgs,
  username,
  wallpaper,
}:
let
  exec = [
    "${pkgs.autotiling}/bin/autotiling"
    "${pkgs.dex}/bin/dex --autostart --environment i3"
    "${pkgs.dunst}/bin/dunst"
    "${pkgs.feh}/bin/feh --bg-tile ${wallpaper}"
    "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
    "${pkgs.xorg.xset}/bin/xset s 480 dpms 600 600 600"
    "${pkgs.xss-lock}/bin/xss-lock -l blur-lock"
  ];

  mkExecLine = x: "exec --no-startup-id ${x}";
  mkExec = xs: builtins.concatStringsSep "\n" (map mkExecLine xs);
in
{
  config = mkExec exec;
}
