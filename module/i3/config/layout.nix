{ username, palette, ... }:
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

    set $background     ${palette.background}
    set $foreground     ${palette.foreground}
    set $black          ${palette.black}
    set $red            ${palette.red}
    set $green          ${palette.green}
    set $yellow         ${palette.yellow}
    set $blue           ${palette.blue}
    set $magenta        ${palette.magenta}
    set $cyan           ${palette.cyan}
    set $white          ${palette.white}
    set $brightBlack    ${palette.brightBlack}
    set $brightRed      ${palette.brightRed}
    set $brightYellow   ${palette.brightYellow}
    set $brightBlue     ${palette.brightBlue}
    set $brightMagenta  ${palette.brightMagenta}
    set $brightCyan     ${palette.brightCyan}
    set $brightWhite    ${palette.brightWhite}

    # class                 border       bground      text          indicator     child_border
    client.focused          $blue        $background  $brightWhite  $brightBlack  $brightBlack
    client.unfocused        $background  $background  $brightBlack  $black        $black
    client.focused_inactive $background  $background  $brightBlack  $black        $black
    client.urgent           $red         $red         $brightWhite  $yellow       $yellow

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
            separator          $magenta
            background         $black
            statusline         $brightWhite

            # class              border        bg            txt           indicator
            focused_workspace    $brightBlack  $brightBlack  $black        $magenta
            active_workspace     $blue         $brightBlack  $black        $magenta
            inactive_workspace   $black        $black        $brightBlack  $magenta
            urgent_workspace     $red          $red          $brightWhite  $magenta
        }
    }
  '';
}
