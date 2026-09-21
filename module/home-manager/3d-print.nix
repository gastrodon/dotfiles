{ pkgs, ... }:
let
  # Kept in sync with the pin in claude.nix's inkmcp MCP server — the extension
  # (run inside Inkscape's own bundled python) and the MCP server (talks to it
  # over D-Bus) come from the same repo and must match.
  inkmcpSrc = pkgs.fetchFromGitHub {
    owner = "Shriinivas";
    repo = "inkmcp";
    rev = "a46287a17e39a04f940887f2197552f45f3d448c";
    hash = "sha256-MtstM8m+9nM6O8Lb44vIFJfl8YImfnvxX2+GwCyFDog=";
  };
in
{
  home.file.".config/inkscape/extensions/inkscape_mcp.py".source = "${inkmcpSrc}/inkscape_mcp.py";
  home.file.".config/inkscape/extensions/inkscape_mcp.inx".source = "${inkmcpSrc}/inkscape_mcp.inx";
  home.file.".config/inkscape/extensions/inkmcp".source = "${inkmcpSrc}/inkmcp";

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
