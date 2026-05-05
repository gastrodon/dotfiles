{ pkgs, lib, ... }:
{
  options.desktop = {
    terminal = lib.mkOption {
      type = lib.types.package;
      default = pkgs.xterm;
    };

    hasPrivateKeys = lib.mkEnableOption "redirect GitHub HTTPS to SSH in git config";

    hasBattery = lib.mkEnableOption "battery and brightness controls";

    extra.i3config = lib.mkOption {
      type = lib.types.attrs;
      default = { };
    };
  };
}
