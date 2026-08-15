{ pkgs, ... }:
{
  home.packages = with pkgs; [
    cura # slicer
    openscad
    freecad
  ];
}
