{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./factorio.nix
    ./black-ops.nix
    ./fallout-4.nix
    ./black-ops-2.nix
  ];
}
