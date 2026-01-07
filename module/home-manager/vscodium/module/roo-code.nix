{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.programs.vscodium.module.roo-code;
in
{
  options.programs.vscodium.module.roo-code = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Roo Code AI assistant";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.vscodium.bundles.roo-code = {
      enable = true;
      extensions = with pkgs.vscode-extensions; [
        rooveterinaryinc.roo-cline
      ];
      packages = [ ];
    };

    programs.vscode.profiles.default.userSettings = {
      "roo-cline.allowedCommands" = [
        "git log"
        "git diff"
        "git show"
      ];
      "roo-cline.deniedCommands" = [ ];
      "diffEditor.renderSideBySide" = false;
    };
  };
}
