{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  packages = with pkgs; [
    git
    cargo-edit
    cargo-watch
  ];

  languages.rust = {
    enable = true;
    components = [
      "rustc"
      "cargo"
      "clippy"
      "rustfmt"
      "rust-analyzer"
    ];
  };

  enterShell = ''
    echo "Rust development environment loaded"
    rustc --version
    cargo --version
  '';

  git-hooks.hooks = {
    rustfmt.enable = true;
    clippy.enable = true;
    nixfmt.enable = true;

    ssh-ip-update = {
      enable = true;
      name = "ssh-ip-update";
      entry = "${./hooks/pre-commit}";
      language = "system";
      pass_filenames = false;
      always_run = true;
      stages = [ "pre-commit" ];
    };
  };
}
