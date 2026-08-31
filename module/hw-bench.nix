# Hardware bench — the host a device-under-test is physically wired to (stone today; a Pi later).
# Opt-in per host with `hwBench.enable = true;`. Three jobs:
#
#   1. toolchain  — build/flash/talk to MCUs. Go-first (tinygo for AVR/ARM MCUs), with
#      arduino-cli + avrdude underneath and esptool for the ESP32-S2 side (HD-WF1).
#   2. stable names — /dev/hw-bench/* symlinks, so scripts and agents stop chasing
#      ttyACM0 -> ttyACM1 renumbering across replugs.
#   3. eyes — a bench camera plus `bench-snap`, so an agent can observe the hardware
#      directly (LED state, stepper motion, a multimeter's LCD) instead of inferring it.
#
# Note: tinygo targets bare-metal MCUs (AVR, RP2040, ESP32...). A Raspberry Pi running
# Linux is NOT a tinygo target — there you use ordinary Go against /dev/gpiochip via
# periph.io or go-gpiocdev, which needs no system package beyond `go` itself.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hwBench;

  # Grab a single still from the bench camera. Prints the path it wrote.
  benchSnap = pkgs.writeShellApplication {
    name = "bench-snap";
    runtimeInputs = [
      pkgs.ffmpeg
      pkgs.coreutils
    ];
    text = ''
      device="${cfg.camera.device}"
      size="${cfg.camera.resolution}"
      outdir="${cfg.camera.snapshotDir}"
      out=""

      while [ $# -gt 0 ]; do
        case "$1" in
          -d|--device) device="$2"; shift 2 ;;
          -o|--output) out="$2"; shift 2 ;;
          -s|--size) size="$2"; shift 2 ;;
          -h|--help) echo "usage: bench-snap [-d DEVICE] [-o FILE] [-s WxH]"; exit 0 ;;
          *) echo "bench-snap: unknown argument $1" >&2; exit 2 ;;
        esac
      done

      if [ ! -e "$device" ]; then
        echo "bench-snap: no camera at $device (is it plugged in? see bench-devices)" >&2
        exit 1
      fi

      if [ -z "$out" ]; then
        mkdir -p "$outdir"
        out="$outdir/snap-$(date +%Y%m%d-%H%M%S).jpg"
      fi

      # Discard the first frames so auto-exposure and white balance settle. Matters when
      # the subject is a dim LED or an LCD rather than a lit room — frame 0 is often useless.
      ffmpeg -hide_banner -loglevel error \
        -f v4l2 -input_format mjpeg -video_size "$size" -i "$device" \
        -vf "select=gte(n\,${toString cfg.camera.warmupFrames})" \
        -frames:v 1 -y "$out"

      echo "$out"
    '';
  };

  # What is actually attached right now, by stable name and by raw device.
  benchDevices = pkgs.writeShellApplication {
    name = "bench-devices";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
      pkgs.usbutils
    ];
    text = ''
      shopt -s nullglob

      echo "== /dev/hw-bench =="
      links=(/dev/hw-bench/*)
      if [ ''${#links[@]} -eq 0 ]; then
        echo "  (nothing claimed by a hw-bench udev rule)"
      else
        for l in "''${links[@]}"; do
          printf '  %-28s -> %s\n' "$l" "$(readlink -f "$l")"
        done
      fi

      echo
      echo "== serial ports =="
      ports=(/dev/ttyACM* /dev/ttyUSB*)
      if [ ''${#ports[@]} -eq 0 ]; then
        echo "  (none)"
      else
        for p in "''${ports[@]}"; do
          desc=$(udevadm info -q property -n "$p" 2>/dev/null \
            | awk -F= '/^ID_VENDOR_ID=/{v=$2} /^ID_MODEL_ID=/{m=$2} /^ID_SERIAL_SHORT=/{s=$2} END{printf "%s:%s serial=%s", v, m, s}')
          printf '  %-16s %s\n' "$p" "$desc"
        done
      fi

      echo
      echo "== video =="
      cams=(/dev/video*)
      if [ ''${#cams[@]} -eq 0 ]; then
        echo "  (none)"
      else
        for c in "''${cams[@]}"; do
          caps=$(udevadm info -q property -n "$c" 2>/dev/null | awk -F= '/^ID_V4L_CAPABILITIES=/{print $2}')
          printf '  %-16s %s\n' "$c" "$caps"
        done
      fi
    '';
  };

  # Live on-screen preview. guvcview also exposes every V4L2 control as a slider
  # (pan/tilt/zoom, exposure, focus), which makes it the aiming tool as well as the viewer.
  benchView = pkgs.writeShellApplication {
    name = "bench-view";
    runtimeInputs = [ pkgs.guvcview ];
    text = ''
      device="${cfg.camera.device}"

      # Fall back to a raw node when the udev symlink is not in place (e.g. pre-switch).
      if [ ! -e "$device" ]; then
        for fallback in /dev/video0 /dev/video1; do
          if [ -e "$fallback" ]; then
            device="$fallback"
            break
          fi
        done
      fi

      if [ ! -e "$device" ]; then
        echo "bench-view: no camera found (see bench-devices)" >&2
        exit 1
      fi

      exec guvcview --device="$device" "$@"
    '';
  };
in
{
  options.hwBench = {
    enable = lib.mkEnableOption "hardware bench: MCU toolchain, stable device symlinks, bench camera";

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ config.identity.username ];
      description = "Users granted serial (dialout) and camera (video) access.";
    };

    camera = {
      device = lib.mkOption {
        type = lib.types.str;
        default = "/dev/hw-bench/cam0";
        description = "Camera bench-snap reads from. Default is the udev-stable symlink.";
      };

      usbId = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "3443:60bb"; # NexiGo N60 FHD on stone
        description = ''
          vendor:product of the bench camera, claimed as cam0. Only the capture-capable
          interface is linked (UVC cameras also expose a metadata node). Null disables.
        '';
      };

      resolution = lib.mkOption {
        type = lib.types.str;
        default = "1920x1080";
        description = "Capture resolution. Detail matters here — this is how the agent reads silkscreen and LCDs.";
      };

      warmupFrames = lib.mkOption {
        type = lib.types.int;
        default = 12;
        description = "Frames to discard before the keeper, letting auto-exposure settle.";
      };

      snapshotDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/hw-bench/snaps";
        description = "Where bench-snap writes when given no -o.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      # Go-first MCU path: tinygo builds and flashes, avrdude does the AVR talking.
      pkgs.go
      pkgs.tinygo
      pkgs.avrdude
      pkgs.arduino-cli
      # ESP32-S2 (HD-WF1) lives on its own flashing protocol.
      pkgs.esptool
      # Serial terminals + enumeration.
      pkgs.picocom
      pkgs.usbutils
      # Vision.
      pkgs.v4l-utils
      pkgs.ffmpeg
      # Live viewer + V4L2 control sliders (FOSS, GPL) — also the aiming tool.
      pkgs.guvcview
      # Logic analyser / DMM capture, for when a protocol needs decoding rather than guessing.
      pkgs.sigrok-cli
      # Host-side serial scripting. pyfirmata/telemetrix are NOT in nixpkgs — if we ever
      # want live pin-poking without a reflash, it is a tinygo firmware + our own protocol,
      # or a package we vendor ourselves.
      (pkgs.python3.withPackages (ps: [ ps.pyserial ]))
      benchSnap
      benchDevices
      benchView
    ];

    # Stable names. Without these, the Uno is ttyACM0 until something else enumerates first.
    services.udev.extraRules = ''
      # Arduino Uno R3 (genuine, ATmega16U2 USB bridge)
      SUBSYSTEM=="tty", ATTRS{idVendor}=="2341", ATTRS{idProduct}=="0043", SYMLINK+="hw-bench/uno", GROUP="dialout", MODE="0660"
      # Clone Unos / USB-UART adapters, kept distinct so a clone never silently takes over "uno".
      SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7523", SYMLINK+="hw-bench/ch340", GROUP="dialout", MODE="0660"
      SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", SYMLINK+="hw-bench/cp2102", GROUP="dialout", MODE="0660"
      SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", SYMLINK+="hw-bench/ftdi", GROUP="dialout", MODE="0660"
      # ESP32-S2 in ROM bootloader — how the HD-WF1 appears once GPIO0 is held low at power-on.
      SUBSYSTEM=="tty", ATTRS{idVendor}=="303a", SYMLINK+="hw-bench/esp32", GROUP="dialout", MODE="0660"
    ''
    + lib.optionalString (cfg.camera.usbId != null) (
      let
        parts = lib.splitString ":" cfg.camera.usbId;
        vid = lib.elemAt parts 0;
        pid = lib.elemAt parts 1;
      in
      ''
        # Bench camera. ID_V4L_CAPABILITIES filters out the metadata node UVC also exposes.
        SUBSYSTEM=="video4linux", ATTRS{idVendor}=="${vid}", ATTRS{idProduct}=="${pid}", ENV{ID_V4L_CAPABILITIES}==":capture:", SYMLINK+="hw-bench/cam0", GROUP="video", MODE="0660"
      ''
    );

    systemd.tmpfiles.rules = [
      "d ${cfg.camera.snapshotDir} 0775 root users - -"
    ];

    users.users = lib.genAttrs cfg.users (_: {
      extraGroups = [
        "dialout"
        "video"
      ];
    });
  };
}
