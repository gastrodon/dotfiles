{ lib, ... }:

let
  # Solarized Dark palette
  palette = {
    background = "#002b36";
    foreground = "#839496";
    black = "#073642";
    red = "#dc322f";
    green = "#859900";
    yellow = "#b58900";
    blue = "#268bd2";
    magenta = "#d33682";
    cyan = "#2aa198";
    white = "#eee8d5";
    brightBlack = "#586e75";
    brightRed = "#cb4b16";
    brightGreen = "#586e75";
    brightYellow = "#657b83";
    brightBlue = "#839496";
    brightMagenta = "#6c71c4";
    brightCyan = "#93a1a1";
    brightWhite = "#fdf6e3";
  };

  # Function to convert palette to ghostty format (strip #)
  toGhosttyColor = color: lib.removePrefix "#" color;
in
{
  programs.ghostty = {
    enable = true;
    
    settings = {
      # Font configuration
      font-family = "Fira Code";
      font-size = 13;
      
      # Solarized Dark colors
      background = toGhosttyColor palette.background;
      foreground = toGhosttyColor palette.foreground;
      
      # Color palette (0-15)
      palette = [
        "0=${toGhosttyColor palette.black}"
        "1=${toGhosttyColor palette.red}"
        "2=${toGhosttyColor palette.green}"
        "3=${toGhosttyColor palette.yellow}"
        "4=${toGhosttyColor palette.blue}"
        "5=${toGhosttyColor palette.magenta}"
        "6=${toGhosttyColor palette.cyan}"
        "7=${toGhosttyColor palette.white}"
        "8=${toGhosttyColor palette.brightBlack}"
        "9=${toGhosttyColor palette.brightRed}"
        "10=${toGhosttyColor palette.brightGreen}"
        "11=${toGhosttyColor palette.brightYellow}"
        "12=${toGhosttyColor palette.brightBlue}"
        "13=${toGhosttyColor palette.brightMagenta}"
        "14=${toGhosttyColor palette.brightCyan}"
        "15=${toGhosttyColor palette.brightWhite}"
      ];
    };
  };
}
