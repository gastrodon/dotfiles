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
    };
  };

  services.libinput.enable = true;

  # Install X11 related packages
  environment.systemPackages = with pkgs; [
    # X11 utilities
    xorg.xrdb # X resources database
    xmodmap # Keyboard mapping
    xorg.xinit # X initialization
    xrandr # Display configuration
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
