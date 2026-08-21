{
  identity,
  palette,
  hostname,
  desktop,
  pkgs,
  lib,
  config,
  ...
}:

let
  ws1 = "1:";
  ws2 = "2:";
  ws3 = "3";
  ws4 = "4";
  ws5 = "5";
  ws6 = "6";
  ws7 = "7";
  ws8 = "8";
  ws9 = "9";
  ws10 = "10";

  wallpaper =
    pkgs.runCommand "wallpaper-scaled"
      {
        buildInputs = [ pkgs.imagemagick ];
      }
      ''
        mkdir -p $out
        convert ${../i3/wall.jpg} -resize 50% $out/wall.jpg
      '';

  mod = "Mod4";

in
{
  xsession.windowManager.i3 = {
    enable = true;
    package = pkgs.i3;

    config = lib.mkMerge [
      {
        modifier = mod;

        fonts = {
          names = [ "iosevka term ss04" ];
          size = 11.0;
        };

        workspaceLayout = "default";

        window = {
          border = 1;
          titlebar = false;
        };

        gaps = {
          inner = 6;
          outer = 3;
        };

        floating.modifier = mod;

        floating.criteria = [
          {
            class = "Yad";
            instance = "yad";
          }
          {
            class = "Galculator";
            instance = "galculator";
          }
          {
            class = "Blueberry.py";
            instance = "blueberry.py";
          }
          {
            class = "Xsane";
            instance = "xsane";
          }
          {
            class = "Pavucontrol";
            instance = "pavucontrol";
          }
          {
            class = "qt5ct";
            instance = "qt5ct";
          }
          {
            class = "Bluetooth-sendto";
            instance = "bluetooth-sendto";
          }
          { class = "Pamac-manager"; }
          { window_role = "About"; }
        ];

        assigns = { };

        colors = {
          background = palette.background;

          focused = {
            border = palette.blue;
            background = palette.background;
            text = palette.brightWhite;
            indicator = palette.brightBlack;
            childBorder = palette.brightBlack;
          };

          unfocused = {
            border = palette.background;
            background = palette.background;
            text = palette.brightBlack;
            indicator = palette.black;
            childBorder = palette.black;
          };

          focusedInactive = {
            border = palette.background;
            background = palette.background;
            text = palette.brightBlack;
            indicator = palette.black;
            childBorder = palette.black;
          };

          urgent = {
            border = palette.red;
            background = palette.red;
            text = palette.brightWhite;
            indicator = palette.yellow;
            childBorder = palette.yellow;
          };
        };

        bars = [
          {
            position = "bottom";
            statusCommand = "i3blocks -c ${config.home.homeDirectory}/.config/i3blocks/config";
            fonts = {
              names = [ "Noto Sans Regular" ];
              size = 10.0;
            };
            trayPadding = 0;
            workspaceNumbers = false;

            colors = {
              background = palette.black;
              statusline = palette.brightWhite;
              separator = palette.magenta;

              focusedWorkspace = {
                border = palette.brightBlack;
                background = palette.brightBlack;
                text = palette.black;
              };

              activeWorkspace = {
                border = palette.blue;
                background = palette.brightBlack;
                text = palette.black;
              };

              inactiveWorkspace = {
                border = palette.black;
                background = palette.black;
                text = palette.brightBlack;
              };

              urgentWorkspace = {
                border = palette.red;
                background = palette.red;
                text = palette.brightWhite;
              };
            };
          }
        ];

        keybindings = lib.mkOptionDefault (
          {
            # Null the default bindsym workspace binds — bindcode equivalents below collide as duplicates otherwise.
            "${mod}+1" = null;
            "${mod}+2" = null;
            "${mod}+3" = null;
            "${mod}+4" = null;
            "${mod}+5" = null;
            "${mod}+6" = null;
            "${mod}+7" = null;
            "${mod}+8" = null;
            "${mod}+9" = null;
            "${mod}+0" = null;
            "${mod}+Shift+1" = null;
            "${mod}+Shift+2" = null;
            "${mod}+Shift+3" = null;
            "${mod}+Shift+4" = null;
            "${mod}+Shift+5" = null;
            "${mod}+Shift+6" = null;
            "${mod}+Shift+7" = null;
            "${mod}+Shift+8" = null;
            "${mod}+Shift+9" = null;
            "${mod}+Shift+0" = null;

            "${mod}+Tab" = "workspace next";
            "${mod}+Shift+Tab" = "workspace prev";

            "${mod}+Return" = "exec --no-startup-id ${desktop.terminal}/bin/${desktop.terminal.pname}";

            "${mod}+q" = "kill";

            "${mod}+Shift+e" = "exec --no-startup-id powermenu";

            "${mod}+Escape" = "exec --no-startup-id blur-lock";

            "${mod}+Shift+c" = "reload";
            "${mod}+Shift+r" = "restart";

            "F1" = "exec --no-startup-id keyhint-2";

            "${mod}+j" = "focus left";
            "${mod}+k" = "focus down";
            "${mod}+l" = "focus up";
            "${mod}+semicolon" = "focus right";

            "${mod}+Left" = "focus left";
            "${mod}+Down" = "focus down";
            "${mod}+Up" = "focus up";
            "${mod}+Right" = "focus right";

            "${mod}+Shift+j" = "move left";
            "${mod}+Shift+k" = "move down";
            "${mod}+Shift+l" = "move up";
            "${mod}+Shift+semicolon" = "move right";

            "${mod}+Shift+Left" = "move left";
            "${mod}+Shift+Down" = "move down";
            "${mod}+Shift+Up" = "move up";
            "${mod}+Shift+Right" = "move right";

            "${mod}+h" = "split h";
            "${mod}+v" = "split v";

            "${mod}+f" = "fullscreen toggle";

            "${mod}+Shift+space" = "floating toggle";

            "${mod}+a" = "focus parent";
            "${mod}+d" = "focus child";

            "${mod}+Shift+n" = "exec --no-startup-id empty_workspace";

            "Print" =
              "exec --no-startup-id ${pkgs.scrot}/bin/scrot ~/Pictures/scrot/%Y-%m-%d-%T.png && ${pkgs.libnotify}/bin/notify-send \"Screenshot saved\" \"~/Pictures/scrot/$(${pkgs.coreutils}/bin/date +\"%Y-%m-%d-%T\").png\"";

            "${mod}+Shift+p" = "exec --no-startup-id power-profiles";

            "${mod}+space" =
              "exec --no-startup-id ${pkgs.rofi}/bin/rofi -modi drun -show drun -config ~/.config/rofi/rofidmenu.rasi";

            "${mod}+t" =
              "exec --no-startup-id ${pkgs.rofi}/bin/rofi -show window -config ~/.config/rofi/rofidmenu.rasi";

            "${mod}+Shift+greater" = "move workspace to output right";
            "${mod}+Shift+less" = "move workspace to output left";

            "${mod}+r" = "mode \"resize\"";
          }
          // lib.optionalAttrs desktop.hasBacklight {
            "XF86MonBrightnessUp" = "exec --no-startup-id sys backlight -w '+5'";
            "XF86MonBrightnessDown" = "exec --no-startup-id sys backlight -w '-5'";
          }
          // lib.optionalAttrs desktop.hasSpeaker {
            "XF86AudioRaiseVolume" = "exec --no-startup-id volume_brightness.sh volume_up";
            "XF86AudioLowerVolume" = "exec --no-startup-id volume_brightness.sh volume_down";
            "XF86AudioMute" = "exec --no-startup-id volume_brightness.sh volume_mute";
            "XF86AudioMicMute" = "exec ${pkgs.alsa-utils}/bin/amixer sset Capture toggle";
            "XF86AudioPlay" = "exec --no-startup-id ${pkgs.playerctl}/bin/playerctl play-pause";
            "XF86AudioNext" = "exec --no-startup-id ${pkgs.playerctl}/bin/playerctl next";
            "XF86AudioPrev" = "exec --no-startup-id ${pkgs.playerctl}/bin/playerctl previous";
          }
        );

        keycodebindings = {
          # number row
          "${mod}+10" = "workspace ${ws1}";
          "${mod}+11" = "workspace ${ws2}";
          "${mod}+12" = "workspace ${ws3}";
          "${mod}+13" = "workspace ${ws4}";
          "${mod}+14" = "workspace ${ws5}";
          "${mod}+15" = "workspace ${ws6}";
          "${mod}+16" = "workspace ${ws7}";
          "${mod}+17" = "workspace ${ws8}";
          "${mod}+18" = "workspace ${ws9}";
          "${mod}+19" = "workspace ${ws10}";

          # numpad
          "${mod}+87" = "workspace ${ws1}";
          "${mod}+88" = "workspace ${ws2}";
          "${mod}+89" = "workspace ${ws3}";
          "${mod}+83" = "workspace ${ws4}";
          "${mod}+84" = "workspace ${ws5}";
          "${mod}+85" = "workspace ${ws6}";
          "${mod}+79" = "workspace ${ws7}";
          "${mod}+80" = "workspace ${ws8}";
          "${mod}+81" = "workspace ${ws9}";
          "${mod}+90" = "workspace ${ws10}";

          # numpad + numlock
          "${mod}+Mod2+87" = "workspace ${ws1}";
          "${mod}+Mod2+88" = "workspace ${ws2}";
          "${mod}+Mod2+89" = "workspace ${ws3}";
          "${mod}+Mod2+83" = "workspace ${ws4}";
          "${mod}+Mod2+84" = "workspace ${ws5}";
          "${mod}+Mod2+85" = "workspace ${ws6}";
          "${mod}+Mod2+79" = "workspace ${ws7}";
          "${mod}+Mod2+80" = "workspace ${ws8}";
          "${mod}+Mod2+81" = "workspace ${ws9}";
          "${mod}+Mod2+90" = "workspace ${ws10}";

          # move container — number row
          "${mod}+Shift+10" = "move container to workspace ${ws1}";
          "${mod}+Shift+11" = "move container to workspace ${ws2}";
          "${mod}+Shift+12" = "move container to workspace ${ws3}";
          "${mod}+Shift+13" = "move container to workspace ${ws4}";
          "${mod}+Shift+14" = "move container to workspace ${ws5}";
          "${mod}+Shift+15" = "move container to workspace ${ws6}";
          "${mod}+Shift+16" = "move container to workspace ${ws7}";
          "${mod}+Shift+17" = "move container to workspace ${ws8}";
          "${mod}+Shift+18" = "move container to workspace ${ws9}";
          "${mod}+Shift+19" = "move container to workspace ${ws10}";

          # move container — numpad
          "${mod}+Shift+87" = "move container to workspace ${ws1}";
          "${mod}+Shift+88" = "move container to workspace ${ws2}";
          "${mod}+Shift+89" = "move container to workspace ${ws3}";
          "${mod}+Shift+83" = "move container to workspace ${ws4}";
          "${mod}+Shift+84" = "move container to workspace ${ws5}";
          "${mod}+Shift+85" = "move container to workspace ${ws6}";
          "${mod}+Shift+79" = "move container to workspace ${ws7}";
          "${mod}+Shift+80" = "move container to workspace ${ws8}";
          "${mod}+Shift+81" = "move container to workspace ${ws9}";
          "${mod}+Shift+90" = "move container to workspace ${ws10}";

          # move container — numpad + numlock
          "${mod}+Shift+Mod2+87" = "move container to workspace ${ws1}";
          "${mod}+Shift+Mod2+88" = "move container to workspace ${ws2}";
          "${mod}+Shift+Mod2+89" = "move container to workspace ${ws3}";
          "${mod}+Shift+Mod2+83" = "move container to workspace ${ws4}";
          "${mod}+Shift+Mod2+84" = "move container to workspace ${ws5}";
          "${mod}+Shift+Mod2+85" = "move container to workspace ${ws6}";
          "${mod}+Shift+Mod2+79" = "move container to workspace ${ws7}";
          "${mod}+Shift+Mod2+80" = "move container to workspace ${ws8}";
          "${mod}+Shift+Mod2+81" = "move container to workspace ${ws9}";
          "${mod}+Shift+Mod2+90" = "move container to workspace ${ws10}";
        };

        modes = {
          resize = {
            # fine (1px)
            "Alt+Shift+j" = "resize shrink width 1 px";
            "Alt+Shift+k" = "resize grow height 1 px";
            "Alt+Shift+l" = "resize shrink height 1 px";
            "Alt+Shift+semicolon" = "resize grow width 1 px";

            # medium (16px)
            "Shift+j" = "resize shrink width 16 px";
            "Shift+k" = "resize grow height 16 px";
            "Shift+l" = "resize shrink height 16 px";
            "Shift+semicolon" = "resize grow width 16 px";

            # coarse (64px)
            "j" = "resize shrink width 64 px";
            "k" = "resize grow height 64 px";
            "l" = "resize shrink height 64 px";
            "semicolon" = "resize grow width 64 px";

            "Escape" = "mode \"default\"";
          };
        };

        startup = [
          {
            command = "${pkgs.autotiling}/bin/autotiling";
            notification = false;
          }
          {
            command = "${pkgs.dex}/bin/dex --autostart --environment i3";
            notification = false;
          }
          {
            command = "${pkgs.dunst}/bin/dunst";
            notification = false;
          }
          {
            command = "${pkgs.feh}/bin/feh --bg-tile ${wallpaper}/wall.jpg";
            notification = false;
          }
          {
            command = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
            notification = false;
          }
          {
            command = "${pkgs.xset}/bin/xset s off -dpms";
            notification = false;
          }
          {
            command = "${pkgs.xss-lock}/bin/xss-lock -l blur-lock";
            notification = false;
          }
        ];
      }
      desktop.extra.i3config
    ];
  };

}
