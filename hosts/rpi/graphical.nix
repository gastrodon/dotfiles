{
  config,
  lib,
  pkgs,
  ...
}:
let
  kioskUrl = "http://homeassistant.local:8123/";

  # Rotate the connected output 90° left; detect its name at runtime (HDMI-1 vs HDMI-A-1 varies by kernel). No input device to wake it, so never blank.
  rotate = pkgs.writeShellScript "rpi-monitor-rotate" ''
    ${pkgs.xorg.xrandr}/bin/xrandr --query \
      | ${pkgs.gawk}/bin/awk '/ connected/ {print $1}' \
      | while read -r out; do
          ${pkgs.xorg.xrandr}/bin/xrandr --output "$out" --rotate left
        done
    ${pkgs.xorg.xset}/bin/xset s off -dpms
  '';

  # Fresh profile each boot so a crash never leaves a "restore session?" prompt over the dashboard.
  kiosk = pkgs.writeShellScript "rpi-kiosk" ''
    profile="$(mktemp -d)"
    exec ${pkgs.firefox}/bin/firefox \
      --profile "$profile" --kiosk "${kioskUrl}"
  '';

  i3Config = pkgs.writeText "i3-rpi-kiosk" ''
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

  # `e` forces the connector on regardless of HDMI HPD — vc4 KMS flaps HPD at boot and X caches it disconnected (black monitor).
  boot.kernelParams = [ "video=HDMI-A-2:1920x1080@60e" ];

  services.libinput.enable = true;
  hardware.graphics.enable = true;

  # BT mouse + speaker; MACs paired interactively on the booted Pi.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  hardware.enableRedistributableFirmware = true;

  # BT speaker audio out (rpi/shared.nix ships no sound stack).
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
}
