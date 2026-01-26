{ pkgs, palette, ... }:
{
  config = ''
    ######################################
    # keybindings for different actions: #
    ######################################

    # Switch/iterate between workspaces
    bindsym $mod+Tab workspace next
    bindsym $mod+Shift+Tab workspace prev

    # Start a terminal
    bindsym $mod+Return exec --no-startup-id ${pkgs.ghostty}/bin/ghostty

    # Kill focused window
    bindsym $mod+q kill

    # Exit-menu
    bindsym $mod+Shift+e exec --no-startup-id powermenu

    # Screen lock
    bindsym $mod+Escape exec --no-startup-id ${pkgs.blur-lock}/bin/blur-lock

    # Reload the configuration file
    bindsym $mod+Shift+c reload

    # Restart i3 inplace (preserves your layout/session, can be used to update i3)
    bindsym $mod+Shift+r restart

    # Keybinding hint in rofi
    bindsym F1 exec --no-startup-id keyhint-2

    # Backlight control
    bindsym XF86MonBrightnessUp exec --no-startup-id brightness-adjust up
    bindsym XF86MonBrightnessDown exec --no-startup-id brightness-adjust down

    # Change focus
    bindsym $mod+j focus left
    bindsym $mod+k focus down
    bindsym $mod+l focus up
    bindsym $mod+semicolon focus right

    # Alternatively, you can use the cursor keys:
    bindsym $mod+Left focus left
    bindsym $mod+Down focus down
    bindsym $mod+Up focus up
    bindsym $mod+Right focus right

    # Move focused window
    bindsym $mod+Shift+j move left
    bindsym $mod+Shift+k move down
    bindsym $mod+Shift+l move up
    bindsym $mod+Shift+semicolon move right

    # Alternatively, you can use the cursor keys:
    bindsym $mod+Shift+Left move left
    bindsym $mod+Shift+Down move down
    bindsym $mod+Shift+Up move up
    bindsym $mod+Shift+Right move right

    # Split in horizontal orientation
    bindsym $mod+h split h

    # Split in vertical orientation
    bindsym $mod+v split v

    # Enter fullscreen mode for the focused container
    bindsym $mod+f fullscreen toggle

    # Toggle tiling / floating
    bindsym $mod+Shift+space floating toggle

    # Focus the parent container
    bindsym $mod+a focus parent
    bindsym $mod+d focus child

    # Open new empty workspace
    bindsym $mod+Shift+n exec --no-startup-id empty_workspace

    # Multimedia Keys

    # Volume
    bindsym XF86AudioRaiseVolume exec --no-startup-id volume_brightness.sh volume_up
    bindsym XF86AudioLowerVolume exec --no-startup-id volume_brightness.sh volume_down

    # Mute
    bindsym XF86AudioMute exec --no-startup-id volume_brightness.sh volume_mute

    # Mic mute toggle
    bindsym XF86AudioMicMute exec ${pkgs.alsa-utils}/bin/amixer sset Capture toggle

    # Audio control
    bindsym XF86AudioPlay exec --no-startup-id ${pkgs.playerctl}/bin/playerctl play-pause
    bindsym XF86AudioNext exec --no-startup-id ${pkgs.playerctl}/bin/playerctl next
    bindsym XF86AudioPrev exec --no-startup-id ${pkgs.playerctl}/bin/playerctl previous

    # Screenshot
    bindsym Print exec --no-startup-id ${pkgs.scrot}/bin/scrot ~/Pictures/scrot/%Y-%m-%d-%T.png && ${pkgs.libnotify}/bin/notify-send "Screenshot saved" "~/Pictures/scrot/$(${pkgs.coreutils}/bin/date +"%Y-%m-%d-%T").png"

    # Power Profiles menu switcher (rofi)
    bindsym $mod+Shift+p exec --no-startup-id power-profiles

    # Theme toggle (light/dark)
    bindsym $mod+Shift+t exec --no-startup-id theme-toggle

    # Switch to workspace with number keys
    bindcode $mod+10    workspace  $ws1
    bindcode $mod+11    workspace  $ws2
    bindcode $mod+12    workspace  $ws3
    bindcode $mod+13    workspace  $ws4
    bindcode $mod+14    workspace  $ws5
    bindcode $mod+15    workspace  $ws6
    bindcode $mod+16    workspace  $ws7
    bindcode $mod+17    workspace  $ws8
    bindcode $mod+18    workspace  $ws9
    bindcode $mod+19    workspace  $ws10

    # Switch to workspace with numpad keys
    bindcode $mod+87 workspace $ws1
    bindcode $mod+88 workspace $ws2
    bindcode $mod+89 workspace $ws3
    bindcode $mod+83 workspace $ws4
    bindcode $mod+84 workspace $ws5
    bindcode $mod+85 workspace $ws6
    bindcode $mod+79 workspace $ws7
    bindcode $mod+80 workspace $ws8
    bindcode $mod+81 workspace $ws9
    bindcode $mod+90 workspace $ws10

    # Switch to workspace with numlock numpad keys
    bindcode $mod+Mod2+87 workspace $ws1
    bindcode $mod+Mod2+88 workspace $ws2
    bindcode $mod+Mod2+89 workspace $ws3
    bindcode $mod+Mod2+83 workspace $ws4
    bindcode $mod+Mod2+84 workspace $ws5
    bindcode $mod+Mod2+85 workspace $ws6
    bindcode $mod+Mod2+79 workspace $ws7
    bindcode $mod+Mod2+80 workspace $ws8
    bindcode $mod+Mod2+81 workspace $ws9
    bindcode $mod+Mod2+90 workspace $ws10

    # Move focused container to workspace
    bindcode $mod+Shift+10    move container to workspace  $ws1
    bindcode $mod+Shift+11    move container to workspace  $ws2
    bindcode $mod+Shift+12    move container to workspace  $ws3
    bindcode $mod+Shift+13    move container to workspace  $ws4
    bindcode $mod+Shift+14    move container to workspace  $ws5
    bindcode $mod+Shift+15    move container to workspace  $ws6
    bindcode $mod+Shift+16    move container to workspace  $ws7
    bindcode $mod+Shift+17    move container to workspace  $ws8
    bindcode $mod+Shift+18    move container to workspace  $ws9
    bindcode $mod+Shift+19    move container to workspace  $ws10

    # Move focused container to workspace with numpad keys
    bindcode $mod+Shift+Mod2+87 	move container to workspace  $ws1
    bindcode $mod+Shift+Mod2+88 	move container to workspace  $ws2
    bindcode $mod+Shift+Mod2+89 	move container to workspace  $ws3
    bindcode $mod+Shift+Mod2+83 	move container to workspace  $ws4
    bindcode $mod+Shift+Mod2+84 	move container to workspace  $ws5
    bindcode $mod+Shift+Mod2+85 	move container to workspace  $ws6
    bindcode $mod+Shift+Mod2+79 	move container to workspace  $ws7
    bindcode $mod+Shift+Mod2+80 	move container to workspace  $ws8
    bindcode $mod+Shift+Mod2+81 	move container to workspace  $ws9
    bindcode $mod+Shift+Mod2+90 	move container to workspace  $ws10

    # Move focused container to workspace with numpad keys
    bindcode $mod+Shift+87 	 move container to workspace  $ws1
    bindcode $mod+Shift+88 	 move container to workspace  $ws2
    bindcode $mod+Shift+89 	 move container to workspace  $ws3
    bindcode $mod+Shift+83 	 move container to workspace  $ws4
    bindcode $mod+Shift+84 	 move container to workspace  $ws5
    bindcode $mod+Shift+85 	 move container to workspace  $ws6
    bindcode $mod+Shift+79 	 move container to workspace  $ws7
    bindcode $mod+Shift+80 	 move container to workspace  $ws8
    bindcode $mod+Shift+81 	 move container to workspace  $ws9
    bindcode $mod+Shift+90 	 move container to workspace  $ws10

    # Move workspace between monitors
    bindsym $mod+Shift+greater move workspace to output right
    bindsym $mod+Shift+less move workspace to output left

    # Resize window mode
    mode "resize" {
        # Fine control with Alt+Shift
        bindsym Alt+Shift+j resize shrink width 1 px
        bindsym Alt+Shift+k resize grow height 1 px
        bindsym Alt+Shift+l resize shrink height 1 px
        bindsym Alt+Shift+semicolon resize grow width 1 px

        # Medium control with Shift
        bindsym Shift+j resize shrink width 16 px
        bindsym Shift+k resize grow height 16 px
        bindsym Shift+l resize shrink height 16 px
        bindsym Shift+semicolon resize grow width 16 px

        # Coarse control
        bindsym j resize shrink width 64 px
        bindsym k resize grow height 64 px
        bindsym l resize shrink height 64 px
        bindsym semicolon resize grow width 64 px

        bindsym Escape mode "default"
    }

    bindsym $mod+r mode "resize"

    #####################################
    # Application menu handled by rofi: #
    #####################################

    # Rofi bindings fancy application menu
    bindsym $mod+space exec --no-startup-id ${pkgs.rofi}/bin/rofi -modi drun -show drun \
            -config ~/.config/rofi/rofidmenu.rasi

    # Rofi bindings for window menu
    bindsym $mod+t exec --no-startup-id ${pkgs.rofi}/bin/rofi -show window \
            -config ~/.config/rofi/rofidmenu.rasi
  '';
}
