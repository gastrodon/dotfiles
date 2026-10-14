{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.programs.zed-editor.module.elm;
in
{
  options.programs.zed-editor.module.elm = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Elm language support";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zed-editor.bundles.elm = {
      enable = true;
      extensions = [ "elm" ];
      packages = with pkgs.elmPackages; [
        elm
        elm-format
        elm-language-server
      ];
    };

    programs.zed-editor.userSettings = {
      lsp.elm-language-server = {
        binary = {
          path = "${pkgs.elmPackages.elm-language-server}/bin/elm-language-server";
          arguments = [ "--stdio" ];
        };
        initialization_options.elmFormatPath = "${pkgs.elmPackages.elm-format}/bin/elm-format";
      };
      languages.Elm.formatter = "language_server";
    };
  };
}
