{ pkgs, lib, ... }:
let
  # nixpkgs' playwright client (python3Packages.playwright) and browser
  # binaries (playwright-driver.browsers) are versioned separately --
  # confirmed close enough here (1.59.0 / 1.59.1) to work together without
  # playwright's own downloader ever running, which is the part that
  # doesn't work in a Nix sandbox anyway (fetches non-reproducibly from
  # Microsoft's CDN at install time).
  webUnwrapped = pkgs.writers.writePython3Bin "web" {
    libraries = [ pkgs.python3Packages.playwright ];
  } (builtins.readFile ./web.py);
in
pkgs.runCommand "web"
{
  nativeBuildInputs = [ pkgs.makeWrapper ];
  meta = with lib; {
    description = "Search (Bing) and fetch pages via a headless browser -- for agent web access without a normal HTTP client";
    license = licenses.mit;
    maintainers = [ ];
  };
} ''
  mkdir -p $out/bin
  makeWrapper ${webUnwrapped}/bin/web $out/bin/web \
    --set PLAYWRIGHT_BROWSERS_PATH ${pkgs.playwright-driver.browsers}
''
