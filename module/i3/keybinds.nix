{ username }:
{
  config = ''
    # i3 config file (v4)
    # Font for window titles
    font iosevka term ss04

    # Set the mod key to the winkey:
    set $mod Mod4

    #####################
    # workspace layout: #
    #####################

    # Default i3 tiling mode:
    workspace_layout default

    ##############################
    # extra options for windows: #
    ##############################

    # Border indicator on windows:
    new_window pixel 1

    # Set inner/outer gaps
    gaps inner 6
    gaps outer 3

    # Use Mouse+$mod to drag floating windows
    floating_modifier $mod

    # Switch/iterate between workspaces
    bindsym $mod+Tab workspace next
    bindsym $mod+Shift+Tab workspace prev

    ######################################
    # keybindings for different actions: #
    ######################################

    # Start a terminal
    bindsym $mod+Return exec --no-startup-id ghostty

    # Kill focused window
    bindsym $mod+q kill

    # Exit-menu
    bindsym $mod+Shift+e exec --no-startup-id powermenu

    # Lock with blur effect
    exec --no-startup-id xss-lock -l blur-lock

    # Reload the configuration file
    bindsym $mod+Shift+c reload

    # Restart i3 inplace (preserves your layout/session, can be used to update i3)
    bindsym $mod+Shift+r restart

    # Keybinding hint in rofi
    bindsym F1 exec --no-startup-id keyhint-2

    # Backlight control
    bindsym XF86MonBrightnessUp exec --no-startup-id volume_brightness.sh brightness_up
    bindsym XF86MonBrightnessDown exec --no-startup-id volume_brightness.sh brightness_down

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
    bindsym XF86AudioMicMute exec amixer sset Capture toggle

    # Audio control
    bindsym XF86AudioPlay exec --no-startup-id playerctl play-pause
    bindsym XF86AudioNext exec --no-startup-id playerctl next
    bindsym XF86AudioPrev exec --no-startup-id playerctl previous

    # Screenshot
    bindsym Print exec --no-startup-id scrot ~/Pictures/scrot/%Y-%m-%d-%T.png && notify-send "Screenshot saved" "~/Pictures/scrot/$(date +"%Y-%m-%d-%T").png"

    # Power Profiles menu switcher (rofi)
    bindsym $mod+Shift+p exec --no-startup-id power-profiles

    ##########################################
    # configuration for workspace behaviour: #
    ##########################################

    # Define names for default workspaces
    set $ws1 "1:"
    set $ws2 "2:"
    set $ws3 "3"
    set $ws4 "4"
    set $ws5 "5"
    set $ws6 "6"
    set $ws7 "7"
    set $ws8 "8"
    set $ws9 "9"
    set $ws10 "10"

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

    #############################################
    # autostart applications/services on login: #
    #############################################

    # Polkit authentication agent
    exec --no-startup-id /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1

    # Dex autostart
    exec --no-startup-id dex --autostart --environment i3

    # Display setup script
    exec --no-startup-id ~/.screenlayout/monitor.sh

    # Set wallpaper
    exec_always --no-startup-id killall feh; feh --bg-tile ~/Pictures/wall.jpg

    # Set power savings for display
    exec --no-startup-id xset s 480 dpms 600 600 600

    # Desktop notifications
    exec --no-startup-id /usr/bin/dunst

    # Autotiling
    exec_always --no-startup-id autotiling

    ##################
    # floating rules #
    ##################

    # Set floating (nontiling) for apps needing it
    for_window [class="Yad" instance="yad"] floating enable
    for_window [class="Galculator" instance="galculator"] floating enable
    for_window [class="Blueberry.py" instance="blueberry.py"] floating enable

    # Set floating (nontiling) for special apps
    for_window [class="Xsane" instance="xsane"] floating enable
    for_window [class="Pavucontrol" instance="pavucontrol"] floating enable
    for_window [class="qt5ct" instance="qt5ct"] floating enable
    for_window [class="Blueberry.py" instance="blueberry.py"] floating enable
    for_window [class="Bluetooth-sendto" instance="bluetooth-sendto"] floating enable
    for_window [class="Pamac-manager"] floating enable
    for_window [window_role="About"] floating enable

    ######################################
    # color settings for bar and windows #
    ######################################

    # Define colors variables:
    set $darkbluetrans	#08052be6
    set $darkblue		#08052b
    set $lightblue		#5294e2
    set $urgentred		#e53935
    set $white		#ffffff
    set $black		#000000
    set $purple		#e345ff
    set $darkgrey		#383c4a
    set $grey		#b0b5bd
    set $mediumgrey		#8b8b8b
    set $yellowbrown	#e1b700

    # Define colors for windows:
    #class		        	border		bground		text		indicator	child_border
    client.focused		    	$lightblue	$darkblue	$white		$mediumgrey	$mediumgrey
    client.unfocused	    	$darkblue	$darkblue	$grey		$darkgrey	$darkgrey
    client.focused_inactive		$darkblue	$darkblue	$grey		$black		$black
    client.urgent		    	$urgentred	$urgentred	$white		$yellowbrown	$yellowbrown

    ############################################
    # bar settings (input comes from i3blocks) #
    ############################################

    bar {
        font pango: Noto Sans Regular 10
        status_command i3blocks -c /home/${username}/.config/i3/i3blocks.conf
        position bottom
        tray_padding 0

        strip_workspace_numbers yes

        colors {
            separator          $purple
            background         $darkgrey
            statusline         $white
            #                          		border 		        bg		txt		indicator
            focused_workspace	$mediumgrey	   	$grey		$darkgrey	$purple
            active_workspace	$lightblue      	$mediumgrey	$darkgrey	$purple
            inactive_workspace	$darkgrey   		$darkgrey	$grey		$purple
            urgent_workspace	$urgentred	    	$urgentred	$white		$purple
        }
    }

    #####################################
    # Application menu handled by rofi: #
    #####################################

    # Rofi bindings fancy application menu
    bindsym $mod+space exec --no-startup-id rofi -modi drun -show drun \
            -config ~/.config/rofi/rofidmenu.rasi

    # Rofi bindings for window menu
    bindsym $mod+t exec --no-startup-id rofi -show window \
            -config ~/.config/rofi/rofidmenu.rasi
  '';
}
