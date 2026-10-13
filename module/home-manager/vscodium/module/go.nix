{
  config,
  pkgs,
  lib,
  ...
}:

let
  ext = import ../extension.nix pkgs;
  cfg = config.programs.vscodium.module.go;
in
{
  options.programs.vscodium.module.go = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Go language support";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.vscodium.bundles.go = {
      enable = true;
      extensions = [ (ext "golang.go") ];
      packages = with pkgs; [
        go
        gopls
        gofumpt
        gotools
        go-tools
        delve
      ];
    };

    programs.vscodium.profiles.default.userSettings = {
      "go.formatTool" = "gofumpt";
      "go.lintTool" = "staticcheck";
      "go.lintOnSave" = "package";
      "gopls" = {
        "ui.semanticTokens" = true;
        "formatting.gofumpt" = true;
      };
      "[go]" = {
        "editor.formatOnSave" = true;
        "editor.codeActionsOnSave" = {
          "source.organizeImports" = "explicit";
        };
      };
      "[go.mod]" = {
        "editor.formatOnSave" = true;
      };
    };
  };
}
