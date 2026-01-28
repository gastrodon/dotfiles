/*
  # i3 Window Manager Scripts Collection

  This module provides utility scripts for i3wm functionality:

  `blur-lock`
  Screen lock with blur effect using i3lock

  `volume-brightness`
  Volume and brightness control with dunst notifications

  `powermenu`
  Rofi-based power menu (shutdown, reboot, suspend, etc.)

  `empty-workspace`
  Find and switch to the first empty workspace

  `keyhint`
  Display i3 keybindings in rofi

  `power-profiles`
  Rofi menu for switching power profiles (performance/balanced/power-saver)

  `battery-block`
  i3blocks battery indicator using sys/rend pipeline

  `brightness-block`
  i3blocks brightness indicator with scroll wheel support
*/
{ pkgs, local, ... }:
let
  blur-lock = pkgs.writeScriptBin "blur-lock" ''
    #!/bin/sh
    ${pkgs.scrot}/bin/scrot /tmp/screenshot.png
    ${pkgs.imagemagick}/bin/convert /tmp/screenshot.png -blur 0x5 /tmp/screenshotblur.png
    ${pkgs.i3lock}/bin/i3lock -i /tmp/screenshotblur.png
    rm /tmp/screenshot.png /tmp/screenshotblur.png
  '';

  volume-brightness = pkgs.writeScriptBin "volume_brightness.sh" ''
    #!/bin/bash
    bar_color="#7f7fff"
    volume_step=1
    brightness_step=2.5
    max_volume=100

    function get_volume {
        ${pkgs.pulseaudio}/bin/pactl get-sink-volume @DEFAULT_SINK@ | grep -Po '[0-9]{1,3}(?=%)' | head -1
    }

    function get_mute {
        ${pkgs.pulseaudio}/bin/pactl get-sink-mute @DEFAULT_SINK@ | grep -Po '(?<=Mute: )(yes|no)'
    }

    function get_brightness {
        ${pkgs.xorg.xbacklight}/bin/xbacklight | grep -Po '[0-9]{1,3}' | head -n 1
    }

    function get_volume_icon {
        volume=$(get_volume)
        mute=$(get_mute)
        if [ "$volume" -eq 0 ] || [ "$mute" == "yes" ] ; then
            volume_icon=""
        elif [ "$volume" -lt 50 ]; then
            volume_icon=""
        else
            volume_icon=""
        fi
    }

    function get_brightness_icon {
        brightness_icon=""
    }

    function show_volume_notif {
        volume=$(get_volume)
        get_volume_icon
        ${pkgs.dunst}/bin/dunstify -i audio-volume-muted-blocking -t 1000 -r 2593 -u normal "$volume_icon $volume%" -h int:value:$volume -h string:hlcolor:$bar_color
    }

    function show_brightness_notif {
        brightness=$(get_brightness)
        get_brightness_icon
        ${pkgs.dunst}/bin/dunstify -t 1000 -r 2593 -u normal "$brightness_icon $brightness%" -h int:value:$brightness -h string:hlcolor:$bar_color
    }

    case $1 in
        volume_up)
        ${pkgs.pulseaudio}/bin/pactl set-sink-mute @DEFAULT_SINK@ 0
        volume=$(get_volume)
        if [ $(( "$volume" + "$volume_step" )) -gt $max_volume ]; then
            ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ $max_volume%
        else
            ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ +$volume_step%
        fi
        show_volume_notif
        ;;

        volume_down)
        ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ -$volume_step%
        show_volume_notif
        ;;

        volume_mute)
        ${pkgs.pulseaudio}/bin/pactl set-sink-mute @DEFAULT_SINK@ toggle
        show_volume_notif
        ;;

        brightness_up)
        ${pkgs.xorg.xbacklight}/bin/xbacklight -inc $brightness_step -time 0
        show_brightness_notif
        ;;

        brightness_down)
        ${pkgs.xorg.xbacklight}/bin/xbacklight -dec $brightness_step -time 0
        show_brightness_notif
        ;;
    esac
  '';

  powermenu = pkgs.writeScriptBin "powermenu" ''
    #!/usr/bin/env bash

    ROFI_OPTIONS="-theme ~/.config/rofi/powermenu.rasi"

    shutdown=" Shutdown"
    reboot=" Reboot"
    suspend=" Suspend"
    hibernate=" Hibernate"
    lock=" Lock"
    logout=" Logout"
    cancel=" Cancel"

    options="$shutdown\n$reboot\n$suspend\n$hibernate\n$lock\n$logout\n$cancel"

    selected=$(echo -e "$options" | ${pkgs.rofi}/bin/rofi -dmenu -i -p "Power Menu" $ROFI_OPTIONS)

    case $selected in
        $shutdown)
            ${pkgs.systemd}/bin/systemctl poweroff
            ;;
        $reboot)
            ${pkgs.systemd}/bin/systemctl reboot
            ;;
        $suspend)
            ${pkgs.systemd}/bin/systemctl suspend
            ;;
        $hibernate)
            ${pkgs.systemd}/bin/systemctl hibernate
            ;;
        $lock)
            ${blur-lock}/bin/blur-lock
            ;;
        $logout)
            ${pkgs.i3}/bin/i3-msg exit
            ;;
    esac
  '';

  empty-workspace = pkgs.writeScriptBin "empty_workspace" ''
    #!/usr/bin/env bash
    MAX_DESKTOPS=20
    WORKSPACES=$(${pkgs.coreutils}/bin/seq -s '\n' 1 1 $MAX_DESKTOPS)

    EMPTY_WORKSPACE=$( (${pkgs.i3}/bin/i3-msg -t get_workspaces | ${pkgs.coreutils}/bin/tr ',' '\n' | ${pkgs.gnugrep}/bin/grep num | ${pkgs.gawk}/bin/awk -F:  '{print int($2)}' ; \
                echo -e $WORKSPACES ) | ${pkgs.coreutils}/bin/sort -n | ${pkgs.coreutils}/bin/uniq -u | ${pkgs.coreutils}/bin/head -n 1)

    ${pkgs.i3}/bin/i3-msg workspace $EMPTY_WORKSPACE
  '';

  keyhint = pkgs.writeScriptBin "keyhint-2" ''
    #!/usr/bin/env bash
    I3_CONFIG=/etc/i3/config
    mod_key=$(${pkgs.gnused}/bin/sed -nre 's/^set \$mod (.*)/\1/p' $I3_CONFIG)
    ${pkgs.gnugrep}/bin/grep "^bindsym\|^bindcode" $I3_CONFIG \
        | ${pkgs.gnused}/bin/sed "s/-\(-\w\+\)\+//g;s/\$mod/$mod_key/g;s/Mod1/Alt/g;s/exec //;s/bindsym //;s/bindcode //;s/^\s\+//;s/^\([^ ]\+\) \(.\+\)$/\2: \1/;s/^\s\+//" \
        | ${pkgs.coreutils}/bin/tr -s ' ' \
        | ${pkgs.rofi}/bin/rofi -dmenu -theme ~/.config/rofi/rofikeyhint.rasi
  '';

  power-profiles = pkgs.writeScriptBin "power-profiles" ''
    #!/usr/bin/env bash

    ROFI_OPTIONS="-theme ~/.config/rofi/power-profiles.rasi"

    performance=" Performance"
    balanced=" Balanced"
    powersaver=" Power Saver"
    cancel=" Cancel"

    options="$performance\n$balanced\n$powersaver\n$cancel"

    selected=$(echo -e "$options" | ${pkgs.rofi}/bin/rofi -dmenu -i -p "Power Profile" $ROFI_OPTIONS)

    case $selected in
        $performance)
            ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set performance 2>/dev/null || echo "power-profiles-daemon not available"
            ;;
        $balanced)
            ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced 2>/dev/null || echo "power-profiles-daemon not available"
            ;;
        $powersaver)
            ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set power-saver 2>/dev/null || echo "power-profiles-daemon not available"
            ;;
    esac
  '';

  battery-block = pkgs.writeScriptBin "battery-block" ''
    #!/usr/bin/env bash
    battery_json=$(${local.sys}/bin/sys --format json battery)
    percent=$(echo "$battery_json" | ${pkgs.jq}/bin/jq .percent)
    state=$(echo "$battery_json" | ${pkgs.jq}/bin/jq -r .state)

    if [ "$state" = "charging" ] || [ "$state" = "full" ]; then
        icon=""
    else
        icon=""
    fi

    echo "$icon $(echo "$percent" | ${local.rend}/bin/rend bars --min 0 --max 100 --count 10)"
  '';

  brightness-block = pkgs.writeScriptBin "brightness-block" ''
    #!/usr/bin/env bash
    case $BLOCK_BUTTON in
        4)
            ${local.sys}/bin/sys backlight --write +5
            ;;
        5)
            current=$(${local.sys}/bin/sys --format json backlight | ${pkgs.jq}/bin/jq .percentage)
            if (( $(echo "$current > 10" | ${pkgs.bc}/bin/bc -l) )); then
                ${local.sys}/bin/sys backlight --write -5
            fi
            ;;
    esac

    echo " $(${local.sys}/bin/sys --format json backlight | ${pkgs.jq}/bin/jq .percentage | ${local.rend}/bin/rend bars --min 0 --max 100 --count 10)"
  '';

in
{
  inherit
    blur-lock
    volume-brightness
    powermenu
    empty-workspace
    keyhint
    power-profiles
    battery-block
    brightness-block
    ;

  scripts = [
    blur-lock
    volume-brightness
    powermenu
    empty-workspace
    keyhint
    power-profiles
    battery-block
    brightness-block
  ];
}
