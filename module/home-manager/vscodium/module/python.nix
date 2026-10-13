{
  config,
  pkgs,
  lib,
  ...
}:

let
  ext = import ../extension.nix pkgs;
  cfg = config.programs.vscodium.module.python;
in
{
  options.programs.vscodium.module.python = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Python language support";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.vscodium.bundles.python = {
      enable = true;
      extensions = map ext [
        "ms-python.python"
        "charliermarsh.ruff"
        "detachhead.basedpyright"
      ];
      packages = with pkgs; [
        python3
        ruff
        basedpyright
      ];
    };

    programs.vscodium.profiles.default.userSettings = {
      "[python]" = {
        "editor.formatOnSave" = true;
        "editor.defaultFormatter" = "charliermarsh.ruff";
      };
    };
  };
}
