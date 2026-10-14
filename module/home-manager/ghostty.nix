{
  desktop,
  palette,
  lib,
  ...
}:

lib.mkIf (desktop.terminal.pname == "ghostty") {
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
