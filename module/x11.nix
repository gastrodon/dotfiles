{ palette }:
{
  config,
  pkgs,
  ...
}:
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
    *background: ${palette.background}
    *foreground: ${palette.brightBlue}
    *fadeColor: ${palette.background}
    *cursorColor: ${palette.brightCyan}
    *pointerColorBackground: ${palette.brightBlack}
    *pointerColorForeground: ${palette.brightCyan}

    ! Black + DarkGrey
    *color0:  ${palette.black}
    *color8:  ${palette.background}
    ! DarkRed + Red
    *color1:  ${palette.red}
    *color9:  ${palette.brightRed}
    ! DarkGreen + Green
    *color2:  ${palette.green}
    *color10: ${palette.brightBlack}
    ! DarkYellow + Yellow
    *color3:  ${palette.yellow}
    *color11: ${palette.brightYellow}
    ! DarkBlue + Blue
    *color4:  ${palette.blue}
    *color12: ${palette.brightBlue}
    ! DarkMagenta + Magenta
    *color5:  ${palette.magenta}
    *color13: ${palette.brightMagenta}
    ! DarkCyan + Cyan
    *color6:  ${palette.cyan}
    *color14: ${palette.brightCyan}
    ! LightGrey + White
    *color7:  ${palette.white}
    *color15: ${palette.brightWhite}
  '';

  # Cursor configuration
  environment.etc."X11/Xresources.d/00-cursor".text = ''
    ! Cursor configuration
    Xcursor.size: 18
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

  # Install X11 related packages
  environment.systemPackages = with pkgs; [
    # X11 utilities
    xorg.xrdb # X resources database
    xorg.xmodmap # Keyboard mapping
    xorg.xinit # X initialization
    xorg.xrandr # Display configuration
    xclip # Clipboard utility

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
