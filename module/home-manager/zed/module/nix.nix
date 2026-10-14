{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.programs.zed-editor.module.nix;
in
{
  options.programs.zed-editor.module.nix = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Nix language support";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zed-editor.bundles.nix = {
      enable = true;
      extensions = [ "nix" ];
      packages = with pkgs; [
        nixd
        nixfmt
      ];
    };

    programs.zed-editor.userSettings = {
      lsp.nixd = {
        binary.path = "${pkgs.nixd}/bin/nixd";
        settings.nixd.formatting.command = [ (lib.getExe pkgs.nixfmt) ];
      };
      languages.Nix = {
        language_servers = [
          "nixd"
          "!nil"
        ];
        formatter = "language_server";
      };
    };
  };
}
