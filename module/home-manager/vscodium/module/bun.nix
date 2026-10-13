{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.programs.vscodium.module.bun;
in
{
  options.programs.vscodium.module.bun = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Bun/TypeScript support";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.vscodium.bundles.bun = {
      enable = true;
      extensions = [ ];
      packages = [ pkgs.bun ];
    };

    programs.vscodium.profiles.default.userSettings = {
      "[typescript]".editor.formatOnSave = true;
      "[typescriptreact]".editor.formatOnSave = true;
    };
  };
}
