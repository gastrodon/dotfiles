{ pkgs, ... }:
{
  environment.systemPackages = [
    # OpenSCAD — parametric CAD via a functional programming language.
    # Design shapes in code, export STL, hand to a slicer. Pairs naturally
    # with hand-written G-code generators for print automation.
    # `openscad-unstable` is the actively developed branch; stable
    # `pkgs.openscad` is stuck at 2021.01.
    pkgs.openscad-unstable

    # Ultimaker Cura slicer. Real `pkgs.cura` was removed from nixpkgs
    # (unmaintained upstream since 2025-10); the AppImage packaging is
    # what ships now. Talks to the Ender 3 over /dev/ttyUSB0 — eva needs
    # the `dialout` group (see module/users.nix).
    pkgs.cura-appimage
  ];
}
