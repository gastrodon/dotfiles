{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.programs.zed-editor.module.rust;
in
{
  options.programs.zed-editor.module.rust = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Rust language support";
    };
  };

  config = lib.mkIf cfg.enable {
    home.sessionVariables = {
      RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
    };

    programs.zed-editor.bundles.rust = {
      enable = true;
      extensions = [ ];
      packages = with pkgs; [
        cargo
        rustc
        rustfmt
        clippy
        rust-analyzer
        lldb
        gcc
      ];
    };

    programs.zed-editor.userSettings = {
      lsp.rust-analyzer = {
        binary.path = "${pkgs.rust-analyzer}/bin/rust-analyzer";
        initialization_options = {
          check.command = "clippy";
          rustc.source = "${pkgs.rustPlatform.rustLibSrc}";
          inlayHints.typeHints.enable = false;
          rustfmt.rangeFormatting.enable = true;
          typing.autoClosingAngleBrackets.enable = true;
        };
      };
      dap.CodeLLDB.binary = "${pkgs.vscode-extensions.vadimcn.vscode-lldb}/share/vscode/extensions/vadimcn.vscode-lldb/adapter/codelldb";
      read_only_files = [
        "**/.cargo/registry/src/**/*.rs"
        "**/lib/rustlib/src/rust/library/**/*.rs"
      ];
    };
  };
}
