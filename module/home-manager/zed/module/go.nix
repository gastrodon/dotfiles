{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.programs.zed-editor.module.go;
in
{
  options.programs.zed-editor.module.go = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Go language support";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zed-editor.bundles.go = {
      enable = true;
      extensions = [ ];
      packages = with pkgs; [
        go
        gopls
        gofumpt
        gotools
        go-tools
        delve
      ];
    };

    programs.zed-editor.userSettings = {
      lsp.gopls.initialization_options = {
        gofumpt = true;
        staticcheck = true;
        "ui.semanticTokens" = true;
      };
      languages.Go = {
        formatter = "language_server";
        code_actions_on_format."source.organizeImports" = true;
      };
      languages."Go Mod".formatter = "language_server";
    };
  };
}
