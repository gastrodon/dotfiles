{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # openscad lives in module/cad.nix (openscad-unstable, system-level) —
    # declaring it here too just shadows that on $PATH with the older
    # stable build, since per-user profile dirs come first in PATH order.
    freecad
  ];
}
