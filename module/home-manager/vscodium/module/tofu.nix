{
  config,
  pkgs,
  lib,
  ...
}:

let
  ext = import ../extension.nix pkgs;
  cfg = config.programs.vscodium.module.tofu;
in
{
  options.programs.vscodium.module.tofu = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable OpenTofu/HCL language support";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.vscodium.bundles.tofu = {
      enable = true;
      extensions = [ (ext "hashicorp.terraform") ];
      packages = with pkgs; [
        opentofu
        terraform-ls
        tflint
      ];
    };

    programs.vscodium.profiles.default.userSettings = {
      "terraform.experimentalFeatures.validateOnSave" = true;
      "terraform.languageServer.enable" = true;
      "[terraform]" = {
        "editor.formatOnSave" = true;
        "editor.defaultFormatter" = "hashicorp.terraform";
      };
      "[terraform-vars]" = {
        "editor.formatOnSave" = true;
        "editor.defaultFormatter" = "hashicorp.terraform";
      };
    };
  };
}
