# i3 Window Manager Configuration
# Configures i3 window manager with everything needed for a complete desktop environment

{ config, pkgs, ... }:

{
  # Enable i3 window manager
  services.xserver.windowManager.i3 = {
    enable = true;
    package = pkgs.i3;
    extraPackages = with pkgs; [
      i3status        # Status bar
      i3lock          # Screen locker
      i3blocks        # Alternative status bar
    ];
  };

  # Install i3 and essential desktop packages
  environment.systemPackages = with pkgs; [
    # Window manager components
    i3              # i3 window manager
    i3status        # Status bar
    i3lock          # Screen locker
    i3blocks        # Alternative status bar
    
    # Application launchers
    dmenu           # Simple application launcher
    rofi            # Advanced application launcher (preferred)
    
    # Terminal emulators
    ghostty         # Modern GPU-accelerated terminal (recommended)
    xterm           # Fallback terminal
    
    # Essential utilities
    feh             # Image viewer and wallpaper setter
    scrot           # Screenshot utility
    picom           # Compositor for transparency and effects
    
    # System utilities
    pavucontrol     # Volume control GUI (works with PipeWire)
    networkmanagerapplet  # NetworkManager system tray applet
    
    # File management
    pcmanfm         # Lightweight file manager
    
    # Clipboard
    xclip           # Clipboard utility for X
    
    # Notifications
    dunst           # Notification daemon
    libnotify       # Send desktop notifications
  ];

  # Enable compositor for better visual effects
  # Uncomment if you want transparency and shadows
  # services.picom = {
  #   enable = true;
  #   fade = true;
  #   shadow = true;
  #   fadeDelta = 4;
  # };

  # Default applications
  environment.variables = {
    # Set default terminal for i3-sensible-terminal
    TERMINAL = "ghostty";
  };

  # Enable sound with PipeWire (modern audio system)
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };
  
  # Fonts for i3 and applications
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
    font-awesome        # Icons for i3status/i3blocks
    (nerdfonts.override { fonts = [ "FiraCode" "DroidSansMono" ]; })
  ];
}
