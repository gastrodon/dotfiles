{ pkgs, ... }:
{
  imports = [
    ./memory-gardener.nix
    ./lab-docs-pull.nix
  ];

  home.packages = [
    pkgs.bao-kv-get
    pkgs.bao-kv-get-cached
  ];

  home.sessionVariables.BAO_ADDR = "http://192.168.0.17:8200";
}
