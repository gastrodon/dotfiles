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
    
    # Display manager - using startx approach via .xinitrc
    displayManager = {
      startx.enable = true;
    };
    
    # Configure libinput for touchpad support
    libinput.enable = true;
  };

  # Install X11 related packages
  environment.systemPackages = with pkgs; [
    xorg.xrdb        # X resources database
    xorg.xmodmap     # Keyboard mapping
    xorg.xinit       # X initialization
    xterm            # Basic terminal
  ];
}
