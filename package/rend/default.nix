{ pkgs, lib, ... }:

pkgs.rustPlatform.buildRustPackage {
  pname = "rend";
  version = "0.1.0";

  src = ./.;

  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  nativeBuildInputs = [ pkgs.gcc ];

  meta = with lib; {
    description = "Rendering utility for visual representations";
    license = licenses.mit;
    maintainers = [ ];
  };
}
