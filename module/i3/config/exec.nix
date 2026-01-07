{ username, wallpaper }:
let
  exec = [
    "xss-lock -l blur-lock"
    "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
    "dex --autostart --environment i3"
    "feh --bg-tile ${wallpaper}"
    "xset s 480 dpms 600 600 600"
    "/usr/bin/dunst"
    "autotiling"
  ];

  mkExecLine = x: "exec --no-startup-id ${x}";
  mkExec = xs: builtins.concatStringsSep "\n" (map mkExecLine xs);
in
{
  config = mkExec exec;
}
