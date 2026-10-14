{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.programs.zed-editor.module.python;
in
{
  options.programs.zed-editor.module.python = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Python language support";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zed-editor.bundles.python = {
      enable = true;
      extensions = [ ];
      packages = with pkgs; [
        python3
        ruff
        basedpyright
      ];
    };

    programs.zed-editor.userSettings = {
      lsp.basedpyright.binary = {
        path = "${pkgs.basedpyright}/bin/basedpyright-langserver";
        arguments = [ "--stdio" ];
      };
      lsp.ruff.binary = {
        path = "${pkgs.ruff}/bin/ruff";
        arguments = [ "server" ];
      };
      languages.Python = {
        language_servers = [
          "basedpyright"
          "ruff"
          "!pyright"
          "..."
        ];
        formatter.language_server.name = "ruff";
      };
    };
  };
}
