{
  desktop,
  palette,
  lib,
  pkgs,
  ...
}:

let
  # Solarized Light: same ANSI palette, swapped base colors
  light = {
    background = "#fdf6e3";
    foreground = "#657b83";
  };

  # `term-theme [light|dark|toggle]` rewrites the optional theme-override
  # config-file below and reloads every running ghostty with SIGUSR2
  termTheme = pkgs.writeShellScriptBin "term-theme" ''
    f="''${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/theme-override"
    mode="''${1:-toggle}"
    if [ "$mode" = toggle ]; then
      if [ -s "$f" ]; then mode=dark; else mode=light; fi
    fi
    mkdir -p "$(dirname "$f")"
    case "$mode" in
      light) printf 'background = ${light.background}\nforeground = ${light.foreground}\n' > "$f" ;;
      dark) : > "$f" ;;
      *) echo "usage: term-theme [light|dark|toggle]" >&2; exit 2 ;;
    esac
    ${pkgs.procps}/bin/pkill -USR2 -f ghostty || true
  '';
in
lib.mkIf (desktop.terminal.pname == "ghostty") {
  home.packages = [ termTheme ];

  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      font-family = "Fira Code";
      font-size = 10;

      copy-on-select = true;
      mouse-hide-while-typing = true;
      window-inherit-working-directory = false;

      window-decoration = false;
      gtk-titlebar = false;
      window-padding-x = 0;
      window-padding-y = 0;
      window-show-tab-bar = "auto";

      # servers lack xterm-ghostty terminfo
      shell-integration-features = "ssh-env,ssh-terminfo";

      background = palette.background;
      foreground = palette.foreground;

      # written by term-theme; later files override the colors above
      config-file = "?theme-override";

      palette = lib.imap0 (i: c: "${toString i}=${palette.${c}}") [
        "black"
        "red"
        "green"
        "yellow"
        "blue"
        "magenta"
        "cyan"
        "white"
        "brightBlack"
        "brightRed"
        "brightGreen"
        "brightYellow"
        "brightBlue"
        "brightMagenta"
        "brightCyan"
        "brightWhite"
      ];
    };
  };
}
