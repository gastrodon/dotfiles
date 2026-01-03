{ config, pkgs, ... }:
let
  # Solarized Dark color palette
  colors = {
    background = {
      dark = "#002b36";
      light = "#fdf6e3";
    };

    highlight = {
      dark = "#073642";
      light = "#eee8d5";
    };

    content = {
      primary = "#657b83";
      emphasis = "#839496";
      secondary = "#586e75";
      muted = "#93a1a1";
    };

    yellow = "#b58900";
    orange = "#cb4b16";
    red = "#dc322f";
    magenta = "#d33682";
    violet = "#6c71c4";
    blue = "#268bd2";
    cyan = "#2aa198";
    green = "#859900";
  };
in
{
  services.xserver = {
    enable = true;

    xkb = {
      layout = "us";
      variant = "";
    };

    displayManager = {
      lightdm = {
        enable = true; # LightDM detects i3 from services.xserver.windowManager.i3
      };

      sessionCommands = ''
        for f in /etc/X11/Xresources.d/*; do
          ${pkgs.xorg.xrdb}/bin/xrdb -merge "$f"
        done
      '';
    };
  };

  services.libinput.enable = true;

  environment.etc."X11/Xresources.d/00-colors".text = ''
    *background: ${colors.background.dark}
    *foreground: ${colors.content.emphasis}
    *fadeColor: ${colors.background.dark}
    *cursorColor: ${colors.content.muted}
    *pointerColorBackground: ${colors.content.secondary}
    *pointerColorForeground: ${colors.content.muted}

    ! Black + DarkGrey
    *color0:  ${colors.highlight.dark}
    *color8:  ${colors.background.dark}
    ! DarkRed + Red
    *color1:  ${colors.red}
    *color9:  ${colors.orange}
    ! DarkGreen + Green
    *color2:  ${colors.green}
    *color10: ${colors.content.secondary}
    ! DarkYellow + Yellow
    *color3:  ${colors.yellow}
    *color11: ${colors.content.primary}
    ! DarkBlue + Blue
    *color4:  ${colors.blue}
    *color12: ${colors.content.emphasis}
    ! DarkMagenta + Magenta
    *color5:  ${colors.magenta}
    *color13: ${colors.violet}
    ! DarkCyan + Cyan
    *color6:  ${colors.cyan}
    *color14: ${colors.content.muted}
    ! LightGrey + White
    *color7:  ${colors.highlight.light}
    *color15: ${colors.background.light}
  '';

  # Cursor configuration
  environment.etc."X11/Xresources.d/00-cursor".text = ''
    ! Cursor configuration
    Xcursor.size: 18
  '';

  environment.etc."X11/Xresources.d/10-rofi".text = ''
    ! Rofi configuration (Solarized Dark theme)
    rofi.font: iosevka ss04 12
    rofi.padding: 20
    rofi.line-padding: 2
    rofi.color-enabled: true
    rofi.hide-scrollbar: true
    rofi.separator-style: solid

    ! Format: background, border, separator
    rofi.color-window: ${colors.background.dark}, ${colors.blue}, ${colors.background.dark}

    ! Format: bg, fg, bg-alt, highlight-bg, highlight-fg
    rofi.color-normal: ${colors.background.dark}, ${colors.content.emphasis}, ${colors.highlight.dark}, ${colors.blue}, ${colors.background.light}
    rofi.color-urgent: ${colors.background.dark}, ${colors.red}, ${colors.highlight.dark}, ${colors.red}, ${colors.background.light}
    rofi.color-active: ${colors.background.dark}, ${colors.blue}, ${colors.highlight.dark}, ${colors.blue}, ${colors.background.light}
    rofi.kb-cancel: Escape,Alt+F1
  '';

  environment.etc."X11/Xresources.d/10-xterm".text = ''
    ! XTerm configuration
    xterm*termName: xterm-256color
    xterm*font: iosevka term ss04
    xterm*faceName: iosevka term ss04:size=11
    xterm*loginShell: true
    xterm*vt100*geometry: 90x34
    xterm*saveLines: 2000
    xterm*charClass: 33:48,35:48,37:48,43:48,45-47:48,64:48,95:48,126:48
    xterm*eightBitInput: false
  '';

  # URxvt configuration
  environment.etc."X11/Xresources.d/10-urxvt".text = ''
    ! URxvt configuration
    URxvt*saveline: 15000
    URxvt*termName: rxvt-256color
    URxvt*iso14755: false
    URxvt*depth: 32
    URxvt*background: [95]${colors.background.dark}
    URxvt*scrollBar: false
    URxvt*scrollBar_right: false
    URxvt*internalBorder: 15
    URxvt*externalBorder: 0
    URxvt*letterSpace: -1
    URxvt.font: xft:iosevka term ss04:size=13:antialias=true
    URxvt.boldFont: xft:Iosevka Term ss04:size=13:antialias=true:hinting=slight
    URxvt.italicFont: xft:Iosevka Term ss04:size=13:antialias=true:hinting=slight
    URxvt.boldItalicFont: xft:Iosevka Term ss04:size=13:antialias=true:hinting=slight
    URxvt.intensityStyles: false
    URxvt.perl-ext-common: default,clipboard,url-select,keyboard-select
    URxvt.copyCommand: xclip -i -selection clipboard
    URxvt.pasteCommand: xclip -o -selection clipboard
    URxvt.keysym.m-c: perl:clipboard:copy
    URxvt.keysym.m-v: perl:clipboard:paste
    URxvt.urlLauncher: exo-open
    URxvt.underlineURLs: true
    URxvt.urlButton: 1
    URxvt.geometry: 400x400
    URxvt.tabbed.tabbar-fg: 4
    URxvt.tabbed.tabbar-bg: 16
    URxvt.tabbed.tab-fg: 15
    URxvt.tabbed.tab-bg: 4
    URxvt*buffered: false
  '';

  # Install X11 related packages
  environment.systemPackages = with pkgs; [
    # X11 utilities
    xorg.xrdb # X resources database
    xorg.xmodmap # Keyboard mapping
    xorg.xinit # X initialization
    xorg.xrandr # Display configuration
    xclip # Clipboard utility

    # Iosevka fonts (multiple variants)
    (iosevka-bin.override { variant = "SS04"; })
    iosevka-bin # Base iosevka

    # URL launcher for URxvt
    xfce.exo # Provides exo-open

    # URxvt with perl extensions
    rxvt-unicode-unwrapped
  ];

  # Configure URxvt perl extensions
  nixpkgs.config.rxvt-unicode = {
    perlSupport = true;
  };

  # Cursor theme
  environment.etc."X11/cursors".source = "${pkgs.vanilla-dmz}/share/icons/Vanilla-DMZ";
}
