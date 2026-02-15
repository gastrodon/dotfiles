{ config, pkgs, lib, ... }:
{
  imports = [
    # Add game-specific modules here
    ./factorio.nix
  ];
}
