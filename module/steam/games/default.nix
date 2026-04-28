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
  ];
}
