{ pkgs, lib, ... }:
{
  options.desktop = {
    terminal = lib.mkOption {
      type = lib.types.package;
      default = pkgs.xterm;
    };

    hasPrivateKeys = lib.mkEnableOption "redirect GitHub HTTPS to SSH in git config";

    hasBattery = lib.mkEnableOption "battery status";

    hasBacklight = lib.mkEnableOption "backlight/brightness controls";

    hasSpeaker = lib.mkEnableOption "speaker/volume controls";

    claudeDesktop = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Claude Desktop package to install (configured wrapper is built in home-manager/claude.nix). Null disables it.";
    };

    extra.i3config = lib.mkOption {
      type = lib.types.attrs;
      default = { };
    };
  };
}
