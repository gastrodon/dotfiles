{
  palette,
  ...
}:
{
  xresources.properties = {
    # Color definitions (Solarized Dark palette)
    "*background" = palette.background;
    "*foreground" = palette.brightBlue;
    "*fadeColor" = palette.background;
    "*cursorColor" = palette.brightCyan;
    "*pointerColorBackground" = palette.brightBlack;
    "*pointerColorForeground" = palette.brightCyan;

    # Black + DarkGrey
    "*color0" = palette.black;
    "*color8" = palette.background;
    # DarkRed + Red
    "*color1" = palette.red;
    "*color9" = palette.brightRed;
    # DarkGreen + Green
    "*color2" = palette.green;
    "*color10" = palette.brightBlack;
    # DarkYellow + Yellow
    "*color3" = palette.yellow;
    "*color11" = palette.brightYellow;
    # DarkBlue + Blue
    "*color4" = palette.blue;
    "*color12" = palette.brightBlue;
    # DarkMagenta + Magenta
    "*color5" = palette.magenta;
    "*color13" = palette.brightMagenta;
    # DarkCyan + Cyan
    "*color6" = palette.cyan;
    "*color14" = palette.brightCyan;
    # LightGrey + White
    "*color7" = palette.white;
    "*color15" = palette.brightWhite;

    # Cursor configuration
    "Xcursor.size" = 18;

    # XTerm configuration
    "xterm*termName" = "xterm-256color";
    "xterm*font" = "iosevka term ss04";
    "xterm*faceName" = "iosevka term ss04:size=11";
    "xterm*loginShell" = true;
    "xterm*vt100*geometry" = "90x34";
    "xterm*saveLines" = 2000;
    "xterm*charClass" = "33:48,35:48,37:48,43:48,45-47:48,64:48,95:48,126:48";
    "xterm*eightBitInput" = false;
  };
}
