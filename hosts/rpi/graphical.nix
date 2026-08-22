{
  config,
  lib,
  pkgs,
  ...
}:
let
  kioskUrl = "http://homeassistant.local:8123/";

  # DIAL/YouTube-Lounge cast receiver (EVA-186/EVA-187 discovery): shows up in
  # the YouTube/YouTube Music apps' native Cast menu, plays through mpv. See
  # package/cast-receiver for the adapter (yt-cast-receiver -> mpv JSON IPC).
  castReceiver = pkgs.callPackage ../../package/cast-receiver { };
  castDialPort = 4000;

  # The paired BT speaker auto-powers-off after a stretch with no active audio
  # stream (firmware power-saving, not something BlueZ/PipeWire can disable —
  # see EVA-191). A permanent, genuinely-silent loop keeps the A2DP link
  # looking "active" so that timer never fires. This is a separate mpv
  # instance from cast-receiver's own — that one is truly idle between casts,
  # which is exactly the state that would otherwise let the speaker sleep.
  # PipeWire mixes both streams into one output, so silence + real audio is
  # just real audio; nothing to hear when a cast starts.
  silenceLoop = pkgs.runCommand "silence.wav" { nativeBuildInputs = [ pkgs.ffmpeg ]; } ''
    ffmpeg -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 -t 5 -c:a pcm_s16le "$out"
  '';

  # Rotate the connected output 90° left; detect its name at runtime (HDMI-1 vs HDMI-A-1 varies by kernel). No input device to wake it, so never blank.
  rotate = pkgs.writeShellScript "rpi-monitor-rotate" ''
    ${pkgs.xrandr}/bin/xrandr --query \
      | ${pkgs.gawk}/bin/awk '/ connected/ {print $1}' \
      | while read -r out; do
          ${pkgs.xrandr}/bin/xrandr --output "$out" --rotate left
        done
    ${pkgs.xset}/bin/xset s off -dpms
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
  #
  # The Pi 4's onboard Bluetooth hangs off the PL011 UART (ttyAMA0), but nixpkgs'
  # sd-image-aarch64.nix parks a kernel console on it. hci_uart then can't reach the
  # controller: every command times out (-110), the baudrate switch fails, and BlueZ
  # ends up reporting no adapter at all. Keep ttyS0 (mini UART on the GPIO header)
  # and tty0 (HDMI); drop only ttyAMA0.
  #
  # mkForce because kernelParams concatenates and there's no way to subtract a single
  # entry. The non-console values are rebuilt from the options that generate them so
  # they can't drift — but a param appended by some *future* module would be silently
  # dropped, so check here first if a kernel param ever goes missing.
  boot.kernelParams = lib.mkForce [
    "video=HDMI-A-2:1920x1080@60e"
    "console=ttyS0,115200n8"
    "console=tty0"
    "nohibernate"
    "loglevel=${toString config.boot.consoleLogLevel}"
    "lsm=${lib.concatStringsSep "," config.security.lsm}"
  ];

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

  # Dedicated video/audio player (EVA-187): mpv + yt-dlp for playing YouTube
  # URLs with video on the kiosk HDMI output and audio on the paired BT
  # speaker. Packages only for now — hwdec flags, BT sink targeting, and a
  # trigger mechanism are still being tuned hands-on against the real hardware.
  environment.systemPackages = with pkgs; [
    mpv
    yt-dlp
  ];

  # Cast receiver service: audio-only for now (no video/BT-sink tuning done
  # yet — that's EVA-187), self-spawns its own mpv with a fixed IPC socket.
  # Runs as a user unit so it inherits the auto-logged-in eva session's
  # PipeWire (the BT speaker is that session's default sink already).
  systemd.user.services.cast-receiver = {
    description = "DIAL/YouTube-Lounge cast receiver (mpv-backed)";
    wantedBy = [ "default.target" ];
    environment = {
      DEVICE_NAME = "Bedroom Pi";
      DIAL_PORT = toString castDialPort;
      MPV_SOCKET = "%t/mpv-cast.sock";
      MPV_BIN = "${pkgs.mpv}/bin/mpv";
      YTDLP_BIN = "${pkgs.yt-dlp}/bin/yt-dlp";
      AUDIO_ONLY = "1";
    };
    serviceConfig = {
      ExecStart = "${castReceiver}/bin/cast-receiver";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # DIAL HTTP (device discovery/description) + SSDP multicast discovery, so
  # the YouTube/YouTube Music apps can actually find the receiver on the LAN.
  networking.firewall.allowedTCPPorts = [ castDialPort ];
  networking.firewall.allowedUDPPorts = [ 1900 ];

  systemd.user.services.bt-keepalive = {
    description = "Silent keepalive loop to stop the paired BT speaker auto-power-off";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.mpv}/bin/mpv --no-video --no-terminal --loop-file=inf ${silenceLoop}";
      Restart = "always";
      RestartSec = 5;
    };
  };
}
