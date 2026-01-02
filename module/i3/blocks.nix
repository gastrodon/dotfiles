{ pkgs, ... }:
let
  # Disk usage block
  i3blocks-disk = pkgs.writeScriptBin "i3blocks-disk" ''
    #!/usr/bin/env bash
    DIR="''${DIR:-''${BLOCK_INSTANCE}}"
    DIR="''${DIR:-''${HOME}}"
    ALERT_LOW="''${ALERT_LOW:-''${1}}"
    ALERT_LOW="''${ALERT_LOW:-10}"

    LOCAL_FLAG="-l"
    if [ "$1" = "-n" ] || [ "$2" = "-n" ]; then
        LOCAL_FLAG=""
    fi

    ${pkgs.coreutils}/bin/df -h -P $LOCAL_FLAG "$DIR" | ${pkgs.gawk}/bin/awk -v label="$LABEL" -v alert_low=$ALERT_LOW '
    /\/.*/ {
        print label $4
        print label $4
        use=$5
        exit 0
    }
    END {
        gsub(/%$/,"",use)
        if (100 - use < alert_low) {
            print "#FF0000"
        }
    }
    '
  '';

  # Bandwidth block
  i3blocks-bandwidth = pkgs.writeScriptBin "i3blocks-bandwidth" ''
    #!/usr/bin/env bash
    iface="''${BLOCK_INSTANCE}"
    iface="''${IFACE:-$iface}"
    dt="''${DT:-3}"
    unit="''${UNIT:-MB}"
    LABEL="''${LABEL:-<span font='FontAwesome'> </span>}"
    printf_command="''${PRINTF_COMMAND:-"printf \"''${LABEL}%1.0f/%1.0f %s/s\\n\", rx, wx, unit;"}"

    function default_interface {
        ${pkgs.iproute2}/bin/ip route | ${pkgs.gawk}/bin/awk '/^default via/ {print $5; exit}'
    }

    function check_proc_net_dev {
        if [ ! -f "/proc/net/dev" ]; then
            echo "/proc/net/dev not found"
            exit 1
        fi
    }

    check_proc_net_dev

    iface="''${iface:-$(default_interface)}"
    while [ -z "$iface" ]; do
        echo No default interface
        sleep "$dt"
        iface=$(default_interface)
    done

    case "$unit" in
        Kb|Kbit|Kbits)   bytes_per_unit=$((1024 / 8));;
        KB|KByte|KBytes) bytes_per_unit=$((1024));;
        Mb|Mbit|Mbits)   bytes_per_unit=$((1024 * 1024 / 8));;
        MB|MByte|MBytes) bytes_per_unit=$((1024 * 1024));;
        Gb|Gbit|Gbits)   bytes_per_unit=$((1024 * 1024 * 1024 / 8));;
        GB|GByte|GBytes) bytes_per_unit=$((1024 * 1024 * 1024));;
        Tb|Tbit|Tbits)   bytes_per_unit=$((1024 * 1024 * 1024 * 1024 / 8));;
        TB|TByte|TBytes) bytes_per_unit=$((1024 * 1024 * 1024 * 1024));;
        *) echo Bad unit "$unit" && exit 1;;
    esac

    scalar=$((bytes_per_unit * dt))
    init_line=$(cat /proc/net/dev | grep "^[ ]*$iface:")
    if [ -z "$init_line" ]; then
        echo Interface not found in /proc/net/dev: "$iface"
        exit 1
    fi

    init_received=$(${pkgs.gawk}/bin/awk '{print $2}' <<< $init_line)
    init_sent=$(${pkgs.gawk}/bin/awk '{print $10}' <<< $init_line)

    (while true; do cat /proc/net/dev; sleep "$dt"; done) |\
        ${pkgs.coreutils}/bin/stdbuf -oL grep "^[ ]*$iface:" |\
        ${pkgs.gawk}/bin/awk -v scalar="$scalar" -v unit="$unit" -v iface="$iface" '
    BEGIN{old_received='"$init_received"';old_sent='"$init_sent"'}
    {
        received=$2
        sent=$10
        rx=(received-old_received)/scalar;
        wx=(sent-old_sent)/scalar;
        tx=rx+wr;
        old_received=received;
        old_sent=sent;
        if(rx >= 0 && wx >= 0){
            '"$printf_command"';
            fflush(stdout);
        }
    }
    '
  '';

  # Battery block
  i3blocks-battery = pkgs.writeScriptBin "i3blocks-battery" ''
    #!/usr/bin/env python3
    from subprocess import check_output
    import os
    import re

    config = dict(os.environ)
    try:
        status = check_output(['${pkgs.acpi}/bin/acpi'], universal_newlines=True)
    except:
        status = ""

    if not status:
        color = config.get("color_10", "red")
        fulltext = "<span color='{}'>No Battery</span>".format(color)
        percentleft = 100
    else:
        batteries = status.split("\n")
        state_batteries=[]
        percentleft_batteries=[]
        time = ""
        for battery in batteries:
            if battery!="":
                state_batteries.append(battery.split(": ")[1].split(", ")[0])
                commasplitstatus = battery.split(", ")
                if not time:
                    time = commasplitstatus[-1].strip()
                    time = re.match(r"(\d+):(\d+)", time)
                    if time:
                        time = ":".join(time.groups())
                        timeleft = " ({})".format(time)
                    else:
                        timeleft = ""

                p = int(commasplitstatus[1].rstrip("%\n"))
                if p>0:
                    percentleft_batteries.append(p)

        state = state_batteries[0] if state_batteries else "Unknown"
        if percentleft_batteries:
            percentleft = int(sum(percentleft_batteries)/len(percentleft_batteries))
        else:
            percentleft = 0

        color = config.get("color_charging", "yellow")
        FA_LIGHTNING = "<span color='{}'>⚡</span>".format(color)
        FA_PLUG = "🔌"
        FA_BATTERY = "🔋"
        FA_QUESTION = "❓"

        if state == "Discharging":
            fulltext = FA_BATTERY + " "
        elif state == "Full":
            fulltext = FA_PLUG + " "
            timeleft = ""
        elif state == "Unknown":
            fulltext = FA_QUESTION + " " + FA_BATTERY + " "
            timeleft = ""
        else:
            fulltext = FA_LIGHTNING + " " + FA_PLUG + " "

        def color_func(percent):
            if percent < 10:
                return config.get("color_10", "#FFFFFF")
            if percent < 20:
                return config.get("color_20", "#FF3300")
            if percent < 30:
                return config.get("color_30", "#FF6600")
            if percent < 40:
                return config.get("color_40", "#FF9900")
            if percent < 50:
                return config.get("color_50", "#FFCC00")
            if percent < 60:
                return config.get("color_60", "#FFFF00")
            if percent < 70:
                return config.get("color_70", "#FFFF33")
            if percent < 80:
                return config.get("color_80", "#FFFF66")
            return config.get("color_full", "#FFFFFF")

        form = '<span color="{}">{}%</span>'
        fulltext += form.format(color_func(percentleft), percentleft)

    print(fulltext)
    print(fulltext)
    if percentleft < 10:
        exit(33)
  '';

  # Volume block
  i3blocks-volume = pkgs.writeScriptBin "i3blocks-volume" ''
    #!/usr/bin/env bash
    MIXER="default"
    if command -v pulseaudio >/dev/null 2>&1 && pulseaudio --check ; then
        if ${pkgs.alsa-utils}/bin/amixer -D pulse info >/dev/null 2>&1 ; then
            MIXER="pulse"
        fi
    fi

    SCONTROL="''${BLOCK_INSTANCE:-$(${pkgs.alsa-utils}/bin/amixer -D $MIXER scontrols |
                      sed -n "s/Simple mixer control '\([^']*\)',0/\1/p" |
                      head -n1
                    )}"

    capability() {
      ${pkgs.alsa-utils}/bin/amixer -D $MIXER get $SCONTROL |
        sed -n "s/  Capabilities:.*cvolume.*/Capture/p"
    }

    volume() {
      ${pkgs.alsa-utils}/bin/amixer -D $MIXER get $SCONTROL $(capability)
    }

    format() {
      perl_filter='if (/.*\[(\d+%)\] (\[(-?\d+.\d+dB)\] )?\[(on|off)\]/)'
      perl_filter+='{CORE::say $4 eq "off" ? "MUTE" : "'
      perl_filter+='$1'
      perl_filter+='"; exit}'
      output=$(${pkgs.perl}/bin/perl -ne "$perl_filter")
      echo "$LABEL$output"
    }

    case $BLOCK_BUTTON in
      3) ${pkgs.alsa-utils}/bin/amixer -q -D $MIXER sset $SCONTROL $(capability) toggle ;;
      4) ${pkgs.alsa-utils}/bin/amixer -q -D $MIXER sset $SCONTROL $(capability) 5%+ unmute ;;
      5) ${pkgs.alsa-utils}/bin/amixer -q -D $MIXER sset $SCONTROL $(capability) 5%- unmute ;;
    esac

    volume | format
  '';
in
{
  scripts = [
    i3blocks-disk
    i3blocks-bandwidth
    i3blocks-battery
    i3blocks-volume
  ];

  # i3blocks configuration
  config = ''
    # i3blocks config file
    separator=false
    markup=pango

    [simple-2]
    full_text=: :
    color=#717171

    # Disk usage
    [disk]
    label=
    instance=/
    command=i3blocks-disk
    interval=30

    [bandwidth]
    command=i3blocks-bandwidth
    interval=persist

    # Battery indicator
    [battery]
    command=i3blocks-battery
    label=
    interval=30

    [simple-2]
    full_text=: :
    color=#717171

    [pavucontrol]
    full_text=
    command=pavucontrol

    [volume-pulseaudio]
    command=i3blocks-volume
    instance=Master
    interval=1

    [keybindings]
    full_text=
    command=keyhint-2

    [time]
    command=date '+%a %d %b %H:%M:%S'
    interval=1

    [shutdown_menu]
    full_text=
    command=powermenu

    [simple-2]
    full_text=: :
    color=#717171
  '';
}
