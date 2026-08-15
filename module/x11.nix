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

  environment.systemPackages = with pkgs; [
    xorg.xrdb
    xmodmap
    xorg.xinit
    xrandr
    xclip
    xfce.exo # exo-open: URL launcher for URxvt
    rxvt-unicode-unwrapped
  ];

  nixpkgs.config.rxvt-unicode = {
    perlSupport = true;
  };

  environment.etc."X11/cursors".source = "${pkgs.vanilla-dmz}/share/icons/Vanilla-DMZ";
}
