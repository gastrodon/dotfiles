# i3 Window Manager Configuration
# Configures i3 window manager with everything needed for a complete desktop environment

{ config, pkgs, ... }:
let
  # Blur-lock script for i3lock with blur effect
  blur-lock = pkgs.writeScriptBin "blur-lock" ''
    #!/bin/sh

    ${pkgs.scrot}/bin/scrot /tmp/screenshot.png
    ${pkgs.imagemagick}/bin/convert /tmp/screenshot.png -blur 0x5 /tmp/screenshotblur.png
    ${pkgs.i3lock}/bin/i3lock -i /tmp/screenshotblur.png
    rm /tmp/screenshot.png /tmp/screenshotblur.png
  '';
in
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
    rxvt-unicode    # URxvt terminal (configured in Xresources)

    # Essential utilities
    feh             # Image viewer and wallpaper setter
    scrot           # Screenshot utility
    maim            # Alternative screenshot utility
    picom           # Compositor for transparency and effects
    imagemagick     # For blur effects in lock script

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

    # Media control
    playerctl       # Media player control

    # URL launcher for URxvt
    xfce.exo        # Provides exo-open

    # Custom scripts
    blur-lock       # Screen lock with blur effect
  ];

  environment.etc."i3/config".text = ''
    # i3 config file (v4)
    # Font for window titles and bar
    font pango:Iosevka Term SS04 11

    # Mod4 = Super
    set $mod Mod4

    # Use Mouse+$mod to drag floating windows
    floating_modifier $mod

    # Terminal
    bindsym $mod+Return exec ghostty

    # Kill focused window
    bindsym $mod+Shift+q kill

    # Application launcher
    bindsym $mod+d exec --no-startup-id rofi -show drun
    bindsym $mod+Shift+d exec --no-startup-id dmenu_run

    # Change focus (vim keys)
    bindsym $mod+h focus left
    bindsym $mod+j focus down
    bindsym $mod+k focus up
    bindsym $mod+l focus right

    # Change focus (cursor keys)
    bindsym $mod+Left focus left
    bindsym $mod+Down focus down
    bindsym $mod+Up focus up
    bindsym $mod+Right focus right

    # Move focused window (vim keys)
    bindsym $mod+Shift+h move left
    bindsym $mod+Shift+j move down
    bindsym $mod+Shift+k move up
    bindsym $mod+Shift+l move right

    # Move focused window (cursor keys)
    bindsym $mod+Shift+Left move left
    bindsym $mod+Shift+Down move down
    bindsym $mod+Shift+Up move up
    bindsym $mod+Shift+Right move right

    # Split orientation
    bindsym $mod+b split h
    bindsym $mod+v split v

    # Fullscreen
    bindsym $mod+f fullscreen toggle

    # Container layout
    bindsym $mod+s layout stacking
    bindsym $mod+w layout tabbed
    bindsym $mod+e layout toggle split

    # Toggle tiling / floating
    bindsym $mod+Shift+space floating toggle

    # Change focus between tiling / floating windows
    bindsym $mod+space focus mode_toggle

    # Focus parent/child container
    bindsym $mod+a focus parent

    # Workspaces
    set $ws1 "1"
    set $ws2 "2"
    set $ws3 "3"
    set $ws4 "4"
    set $ws5 "5"
    set $ws6 "6"
    set $ws7 "7"
    set $ws8 "8"
    set $ws9 "9"
    set $ws10 "10"

    # Switch to workspace
    bindsym $mod+1 workspace number $ws1
    bindsym $mod+2 workspace number $ws2
    bindsym $mod+3 workspace number $ws3
    bindsym $mod+4 workspace number $ws4
    bindsym $mod+5 workspace number $ws5
    bindsym $mod+6 workspace number $ws6
    bindsym $mod+7 workspace number $ws7
    bindsym $mod+8 workspace number $ws8
    bindsym $mod+9 workspace number $ws9
    bindsym $mod+0 workspace number $ws10

    # Move container to workspace
    bindsym $mod+Shift+1 move container to workspace number $ws1
    bindsym $mod+Shift+2 move container to workspace number $ws2
    bindsym $mod+Shift+3 move container to workspace number $ws3
    bindsym $mod+Shift+4 move container to workspace number $ws4
    bindsym $mod+Shift+5 move container to workspace number $ws5
    bindsym $mod+Shift+6 move container to workspace number $ws6
    bindsym $mod+Shift+7 move container to workspace number $ws7
    bindsym $mod+Shift+8 move container to workspace number $ws8
    bindsym $mod+Shift+9 move container to workspace number $ws9
    bindsym $mod+Shift+0 move container to workspace number $ws10

    # Reload/restart i3
    bindsym $mod+Shift+c reload
    bindsym $mod+Shift+r restart

    # Exit i3
    bindsym $mod+Shift+e exec "i3-nagbar -t warning -m 'Exit i3?' -B 'Yes' 'i3-msg exit'"

    # Lock screen with blur effect
    bindsym $mod+Shift+x exec --no-startup-id blur-lock

    # Resize mode
    mode "resize" {
        bindsym h resize shrink width 10 px or 10 ppt
        bindsym j resize grow height 10 px or 10 ppt
        bindsym k resize shrink height 10 px or 10 ppt
        bindsym l resize grow width 10 px or 10 ppt

        bindsym Left resize shrink width 10 px or 10 ppt
        bindsym Down resize grow height 10 px or 10 ppt
        bindsym Up resize shrink height 10 px or 10 ppt
        bindsym Right resize grow width 10 px or 10 ppt

        bindsym Return mode "default"
        bindsym Escape mode "default"
        bindsym $mod+r mode "default"
    }
    bindsym $mod+r mode "resize"

    # Volume control (PipeWire/PulseAudio)
    bindsym XF86AudioRaiseVolume exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ +5%
    bindsym XF86AudioLowerVolume exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ -5%
    bindsym XF86AudioMute exec --no-startup-id pactl set-sink-mute @DEFAULT_SINK@ toggle
    bindsym XF86AudioMicMute exec --no-startup-id pactl set-source-mute @DEFAULT_SOURCE@ toggle

    # Media player controls
    bindsym XF86AudioPlay exec --no-startup-id playerctl play-pause
    bindsym XF86AudioNext exec --no-startup-id playerctl next
    bindsym XF86AudioPrev exec --no-startup-id playerctl previous

    # Screenshots
    bindsym Print exec --no-startup-id scrot '%Y-%m-%d_%H-%M-%S_screenshot.png' -e 'mv $f ~/Pictures/'
    bindsym $mod+Print exec --no-startup-id scrot -u '%Y-%m-%d_%H-%M-%S_screenshot.png' -e 'mv $f ~/Pictures/'
    bindsym $mod+Shift+Print exec --no-startup-id scrot -s '%Y-%m-%d_%H-%M-%S_screenshot.png' -e 'mv $f ~/Pictures/'

    # Window colors (Gruvbox theme)
    # class                 border  backgr. text    indicator child_border
    client.focused          #458588 #458588 #ebdbb2 #689d6a   #458588
    client.focused_inactive #282828 #282828 #ebdbb2 #282828   #282828
    client.unfocused        #282828 #282828 #928374 #282828   #282828
    client.urgent           #cc241d #cc241d #ebdbb2 #cc241d   #cc241d
    client.placeholder      #000000 #0c0c0c #ffffff #000000   #0c0c0c
    client.background       #282828

    # Window borders
    default_border pixel 2
    default_floating_border pixel 2

    # Gaps (if using i3-gaps)
    # gaps inner 5
    # gaps outer 2

    # Status bar
    bar {
        status_command i3status
        position top
        font pango:Iosevka Term SS04 10

        colors {
            background #282828
            statusline #ebdbb2
            separator  #928374

            #                  border  backgr. text
            focused_workspace  #458588 #458588 #ebdbb2
            active_workspace   #282828 #282828 #ebdbb2
            inactive_workspace #282828 #282828 #928374
            urgent_workspace   #cc241d #cc241d #ebdbb2
            binding_mode       #d79921 #d79921 #282828
        }
    }

    # Autostart applications
    exec --no-startup-id picom -b
    exec --no-startup-id dunst
    exec --no-startup-id nm-applet
    exec --no-startup-id feh --bg-scale ~/Pictures/wall.jpg
  '';

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
    fira-code
    fira-code-symbols
    font-awesome        # Icon font for menubar symbols
    (iosevka-bin.override { variant = "SS04"; })
  ];
}
