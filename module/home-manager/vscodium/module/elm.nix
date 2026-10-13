{
  config,
  pkgs,
  lib,
  ...
}:

let
  ext = import ../extension.nix pkgs;
  cfg = config.programs.vscodium.module.elm;
in
{
  options.programs.vscodium.module.elm = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Elm language support";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.vscodium.bundles.elm = {
      enable = true;
      extensions = [ (ext "elmtooling.elm-ls-vscode") ];
      packages = with pkgs.elmPackages; [
        elm
        elm-format
        elm-language-server
      ];
    };

    programs.vscodium.profiles.default.userSettings = {
      "elmLS.elmFormatPath" = "${pkgs.elmPackages.elm-format}/bin/elm-format";
      "[elm]".editor.formatOnSave = true;
    };
  };
}
