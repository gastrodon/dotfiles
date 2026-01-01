# i3 Window Manager Configuration
# Configures i3 as the window manager

{ config, pkgs, ... }:

{
  # Enable i3 window manager
  services.xserver.windowManager.i3 = {
    enable = true;
    package = pkgs.i3;
  };

  # Install i3 and related packages
  environment.systemPackages = with pkgs; [
    i3              # i3 window manager
    i3status        # Status bar
    i3lock          # Screen locker
    dmenu           # Application launcher (fallback)
    rofi            # Application launcher (preferred)
  ];
}
