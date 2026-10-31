{ pkgs, ... }:
{
  home.packages = with pkgs; [
    freecad

    # OpenSCAD — parametric CAD via a functional programming language.
    # Design shapes in code, export STL, hand to a slicer. Pairs naturally
    # with hand-written G-code generators for print automation.
    # `openscad-unstable` is the actively developed branch; stable
    # `pkgs.openscad` is stuck at 2021.01.
    openscad-unstable

    # Ultimaker Cura slicer. Real `pkgs.cura` was removed from nixpkgs
    # (unmaintained upstream since 2025-10); the AppImage packaging is
    # what ships now. Talks to the Ender 3 over /dev/ttyUSB0 — eva needs
    # the `dialout` group (module/users.nix; a user-account property,
    # unaffected by whether this package is home- or system-scoped).
    cura-appimage

    # Inkscape — for sketching/annotating diagrams by hand when describing
    # geometry in words gets unwieldy (e.g. marking up a dimension or shape
    # feature visually instead). Grouped with the other design tools here
    # since the use case is the same hardware/CAD design workflow, not
    # general graphic design.
    inkscape
  ];
}
