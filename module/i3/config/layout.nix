{ username, wallpaper }:
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
  '';
}
