{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.programs.zed-editor.module.tofu;
in
{
  options.programs.zed-editor.module.tofu = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable OpenTofu/HCL language support";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zed-editor.bundles.tofu = {
      enable = true;
      extensions = [ "terraform" ];
      packages = with pkgs; [
        opentofu
        terraform-ls
        tflint
      ];
    };

    programs.zed-editor.userSettings = {
      lsp.terraform-ls = {
        binary = {
          path = "${pkgs.terraform-ls}/bin/terraform-ls";
          arguments = [ "serve" ];
        };
        initialization_options.experimentalFeatures.validateOnSave = true;
      };
      languages.Terraform.formatter = "language_server";
      languages."Terraform Vars".formatter = "language_server";
    };
  };
}
