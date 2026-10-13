{ pkgs, ... }:
{
  imports = [
    ./memory-gardener.nix
    ./lab-docs-pull.nix
  ];

  home.packages = [
    (import ./bao-kv-get.nix { inherit pkgs; })
    (import ./bao-kv-get-cached.nix { inherit pkgs; })
  ];

  home.sessionVariables.BAO_ADDR = "http://192.168.0.17:8200";
}
