{ desktop, lib, ... }:

let
  palette = {
    background = "002b36";
    foreground = "839496";
    black = "073642";
    red = "dc322f";
    green = "859900";
    yellow = "b58900";
    blue = "268bd2";
    magenta = "d33682";
    cyan = "2aa198";
    white = "eee8d5";
    brightBlack = "586e75";
    brightRed = "cb4b16";
    brightGreen = "586e75";
    brightYellow = "657b83";
    brightBlue = "839496";
    brightMagenta = "6c71c4";
    brightCyan = "93a1a1";
    brightWhite = "fdf6e3";
  };
in
lib.mkIf (desktop.terminal.pname == "ghostty") {
  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      font-family = "Fira Code";
      font-size = 10;

      copy-on-select = true;
      mouse-hide-while-typing = true;

      window-decoration = false;
      gtk-titlebar = false;
      window-padding-x = 0;
      window-padding-y = 0;
      window-show-tab-bar = "auto";

      # Solarized Dark colors
      background = palette.background;
      foreground = palette.foreground;

      # Color palette (0-15)
      palette = [
        "0=${palette.black}"
        "1=${palette.red}"
        "2=${palette.green}"
        "3=${palette.yellow}"
        "4=${palette.blue}"
        "5=${palette.magenta}"
        "6=${palette.cyan}"
        "7=${palette.white}"
        "8=${palette.brightBlack}"
        "9=${palette.brightRed}"
        "10=${palette.brightGreen}"
        "11=${palette.brightYellow}"
        "12=${palette.brightBlue}"
        "13=${palette.brightMagenta}"
        "14=${palette.brightCyan}"
        "15=${palette.brightWhite}"
      ];
    };
  };
}
