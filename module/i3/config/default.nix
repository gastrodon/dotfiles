{ pkgs, username, wallpaper, palette }:

let
  lib = pkgs.lib;

  # Get all .nix files in this directory except default.nix
  configDir = ./.;
  nixFiles = builtins.filter
    (name: name != "default.nix" && lib.hasSuffix ".nix" name)
    (builtins.attrNames (builtins.readDir configDir));

  # Import each config file and extract its .config property
  configs = map
    (file:
      let
        module = import (configDir + "/${file}") { inherit pkgs username wallpaper palette; };
      in
      module.config
    )
    nixFiles;

  # Merge all configs together as a single string
  mergedConfig = lib.concatStringsSep "\n" configs;
in
{
  config = mergedConfig;
}
