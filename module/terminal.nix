{ pkgs, lib, ... }:
{
  options.desktop = {
    terminal = lib.mkOption {
      type = lib.types.package;
      default = pkgs.xterm;
    };

    hasPrivateKeys = lib.mkEnableOption "redirect GitHub HTTPS to SSH in git config";
  };
}
