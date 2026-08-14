{
  config,
  lib,
  pkgs,
  ...
}:
let
  # One monitor on this Pi; rotate whatever output X brings up 90° right
  # (tall). Detect the name at runtime rather than hardcoding HDMI-1 vs
  # HDMI-A-1, which varies by kernel/driver.
  rotate = pkgs.writeShellScript "rpi4b-monitor-rotate" ''
    ${pkgs.xorg.xrandr}/bin/xrandr --query \
      | ${pkgs.gawk}/bin/awk '/ connected/ {print $1}' \
      | while read -r out; do
          ${pkgs.xorg.xrandr}/bin/xrandr --output "$out" --rotate right
        done
  '';

  i3Config = pkgs.writeText "i3-rpi4b" ''
    font pango:monospace 8
    exec_always --no-startup-id ${rotate}
  '';
in
{
  services.xserver = {
    enable = true;
    windowManager.i3.enable = true;
    windowManager.i3.configFile = i3Config;
    displayManager.lightdm.enable = true;
  };

  services.displayManager.autoLogin = {
    enable = true;
    user = config.identity.username;
  };
  services.displayManager.defaultSession = "none+i3";

  services.libinput.enable = true;
  hardware.graphics.enable = true;

  # BT mouse + BT speaker. MACs paired interactively on the booted Pi.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  hardware.enableRedistributableFirmware = true;

  # Audio out for the BT speaker (rpi/shared.nix ships no sound stack).
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
}
