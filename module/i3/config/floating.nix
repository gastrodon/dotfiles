{ ... }:
{
  config = ''
    ##################
    # floating rules #
    ##################

    # Use Mouse+$mod to drag floating windows
    floating_modifier $mod

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
  '';
}
