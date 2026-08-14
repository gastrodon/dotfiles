{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Home Assistant Lovelace dashboard the kiosk points at.
  kioskUrl = "http://homeassistant.local:8123/";

  # One monitor on this Pi; rotate whatever output X brings up 90° left
  # (tall). Detect the name at runtime rather than hardcoding HDMI-1 vs
  # HDMI-A-1, which varies by kernel/driver.
  rotate = pkgs.writeShellScript "rpi4b-monitor-rotate" ''
    ${pkgs.xorg.xrandr}/bin/xrandr --query \
      | ${pkgs.gawk}/bin/awk '/ connected/ {print $1}' \
      | while read -r out; do
          ${pkgs.xorg.xrandr}/bin/xrandr --output "$out" --rotate left
        done
    # No input device to wake a blanked screen — keep it always on.
    ${pkgs.xorg.xset}/bin/xset s off -dpms
  '';

  # Fresh profile each boot so a crash/reboot never triggers a
  # "restore session?" prompt that would sit over the dashboard.
  kiosk = pkgs.writeShellScript "rpi4b-kiosk" ''
    profile="$(mktemp -d)"
    exec ${pkgs.firefox}/bin/firefox \
      --profile "$profile" --kiosk "${kioskUrl}"
  '';

  i3Config = pkgs.writeText "i3-rpi4b" ''
    font pango:monospace 8
    exec_always --no-startup-id ${rotate}
    exec --no-startup-id ${kiosk}
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

  # Force the DRM connector on regardless of HDMI hotplug-detect. The vc4
  # KMS driver otherwise races/flaps HPD at boot and X caches the output as
  # disconnected, leaving the monitor black. Pins the current micro-HDMI port.
  boot.kernelParams = [ "video=HDMI-A-2:1920x1080@60e" ];

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
