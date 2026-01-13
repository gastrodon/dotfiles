{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.programs.vscodium.module.rust;
in
{
  options.programs.vscodium.module.rust = {
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

    programs.vscodium.bundles.rust = {
      enable = true;
      extensions = with pkgs.vscode-extensions; [
        rust-lang.rust-analyzer
        vadimcn.vscode-lldb
      ];
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

    programs.vscode.profiles.default.userSettings = {
      "rust-analyzer.check.command" = "clippy";
      "rust-analyzer.checkOnSave" = true;
      "rust-analyzer.rustc.source" = "${pkgs.rustPlatform.rustLibSrc}";
      "rust-analyzer.debug.engineSettings" = {
        terminal = null;
      };
      "rust-analyzer.inlayHints.typeHints.enable" = false;
      "rust-analyzer.rustfmt.rangeFormatting.enable" = true;
      "rust-analyzer.typing.autoClosingAngleBrackets.enable" = true;
      "rust-client.rustupPath" = "~/.cargo/bin/rustup";
      "rust.clippy_preference" = "on";
      "lldb.suppressUpdateNotifications" = true;
      "files.readonlyInclude" = {
        "**/.cargo/registry/src/**/*.rs" = true;
        "**/lib/rustlib/src/rust/library/**/*.rs" = true;
      };
      "[rust]" = {
        "editor.formatOnSave" = true;
      };
    };
  };
}
