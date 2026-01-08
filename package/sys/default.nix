{ pkgs, lib, ... }:

pkgs.rustPlatform.buildRustPackage {
  pname = "sys";
  version = "0.1.0";

  src = ./.;

  cargoLock = {
    lockFile = ./Cargo.lock;
  };

  nativeBuildInputs = [ pkgs.gcc ];

  meta = with lib; {
    description = "System information utility";
    license = licenses.mit;
    maintainers = [ ];
  };
}
