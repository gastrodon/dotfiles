{
  config,
  pkgs,
  lib,
  ...
}:

let
  ext = import ../extension.nix pkgs;
  cfg = config.programs.vscodium.module.nix;
in
{
  options.programs.vscodium.module.nix = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Nix language support";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.vscodium.bundles.nix-ide = {
      enable = true;
      extensions = [ (ext "jnoortheen.nix-ide") ];
      packages = with pkgs; [
        nixd
        nixfmt
      ];
    };

    programs.vscodium.profiles.default.userSettings = {
      "nix.enableLanguageServer" = true;
      "nix.serverPath" = "nixd";
      "nix.serverSettings".nixd.formatting.command = [ "nixfmt" ];
      "[nix]" = {
        "editor.formatOnSave" = true;
      };
    };
  };
}
