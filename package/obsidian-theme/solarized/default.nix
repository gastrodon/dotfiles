{
  pkgs,
  lib,
  fetchFromGitHub,
}:

pkgs.stdenv.mkDerivation rec {
  pname = "obsidian-solarized";
  version = "1.1.3";

  src = fetchFromGitHub {
    owner = "harmtemolder";
    repo = "obsidian-solarized";
    rev = "v${version}";
    sha256 = "sha256-yfTxl+7hDetDh4g5uha44NvPqdpPlBxlnGdKNeK91N4=";
  };

  installPhase = ''
    mkdir -p $out
    cp manifest.json $out/
    cp theme.css $out/
  '';

  meta = with lib; {
    description = "Solarized theme for Obsidian";
    homepage = "https://github.com/harmtemolder/obsidian-solarized";
    license = licenses.mit;
    maintainers = [ ];
  };
}
