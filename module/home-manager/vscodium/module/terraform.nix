{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.programs.vscodium.module.terraform;
in
{
  options.programs.vscodium.module.terraform = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Terraform/HCL language support";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.vscodium.bundles.terraform = {
      enable = true;
      extensions = with pkgs.vscode-extensions; [
        hashicorp.terraform
      ];
      packages = with pkgs; [
        opentofu
        terraform-ls
        tflint
      ];
    };

    programs.vscode.profiles.default.userSettings = {
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
