{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.programs.zed-editor.module.bun;
in
{
  options.programs.zed-editor.module.bun = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Bun/TypeScript support";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zed-editor.bundles.bun = {
      enable = true;
      extensions = [ ];
      packages = [ pkgs.bun ];
    };

    programs.zed-editor.userSettings = {
      node.path = "${pkgs.nodejs}/bin/node";
      lsp.vtsls.binary = {
        path = "${pkgs.vtsls}/bin/vtsls";
        arguments = [ "--stdio" ];
      };
    };
  };
}
