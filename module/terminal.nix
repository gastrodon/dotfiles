{ pkgs, lib, ... }:
{
  options.desktop = {
    session = lib.mkOption {
      type = lib.types.enum [
        "x11"
        "wayland"
      ];
      default = "x11";
    };

    xwayland = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    terminal = lib.mkOption {
      type = lib.types.package;
      default = pkgs.xterm;
    };

    hasPrivateKeys = lib.mkEnableOption "redirect GitHub HTTPS to SSH in git config";

    hasBattery = lib.mkEnableOption "battery status";

    hasBacklight = lib.mkEnableOption "backlight/brightness controls";

    hasSpeaker = lib.mkEnableOption "speaker/volume controls";

    idleLock = lib.mkEnableOption "locking after 5 minutes idle";

    extra.i3config = lib.mkOption {
      type = lib.types.attrs;
      default = { };
    };

    extra.swayconfig = lib.mkOption {
      type = lib.types.attrs;
      default = { };
    };
  };
}
