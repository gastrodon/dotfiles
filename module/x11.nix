# X11 Window System Configuration
# Configures the X server and display manager

{ config, pkgs, ... }:

{
  # Enable the X11 windowing system
  services.xserver = {
    enable = true;
    
    # Keyboard layout
    layout = "us";
    xkbVariant = "";
    
    # Display manager - LightDM for graphical login
    displayManager = {
      lightdm = {
        enable = true;
        # LightDM will automatically detect i3 from services.xserver.windowManager.i3
      };
    };
    
    # Configure libinput for touchpad support
    libinput.enable = true;
  };

  # Install X11 related packages
  environment.systemPackages = with pkgs; [
    xorg.xrdb        # X resources database
    xorg.xmodmap     # Keyboard mapping
    xorg.xinit       # X initialization
    xorg.xrandr      # Display configuration
    xclip            # Clipboard utility
  ];
}
