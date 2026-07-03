{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Slicer - converts 3D models to printer instructions
    cura

    # Parametric 3D modeling language
    openscad

    # Open-source CAD for constrained mechanical design (AutoCAD alternative)
    # Excellent for designing parts with constraints, parameters, and precise dimensions
    freecad
  ];
}
