{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  # https://devenv.sh/packages/
  packages = with pkgs; [
    git
    cargo-edit # for cargo add/rm/upgrade
    cargo-watch # for watching file changes
  ];

  # https://devenv.sh/languages/
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

  # https://devenv.sh/basics/
  enterShell = ''
    echo "Rust development environment loaded"
    rustc --version
    cargo --version
  '';

  # https://devenv.sh/git-hooks/
  git-hooks.hooks = {
    rustfmt.enable = true;
    clippy.enable = true;
  };

  # See full reference at https://devenv.sh/reference/options/
}
