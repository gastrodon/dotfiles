{
  pkgs,
  username,
  wallpaper,
  palette,
  scripts,
  local,
  ...
}:

let
  lib = pkgs.lib;

  configDir = ./.;
  nixFiles = builtins.filter (name: name != "default.nix" && lib.hasSuffix ".nix" name) (
    builtins.attrNames (builtins.readDir configDir)
  );

  configs = map (
    file:
    let
      module = import (configDir + "/${file}") {
        inherit
          pkgs
          username
          wallpaper
          palette
          scripts
          local
          ;
      };
    in
    module.config
  ) nixFiles;

  mergedConfig = lib.concatStringsSep "\n" configs;
in
{
  config = mergedConfig;
}
