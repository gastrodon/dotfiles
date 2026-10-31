{ lib, rustPlatform }:
rustPlatform.buildRustPackage {
  pname = "sys";
  version = "0.1.0";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./Cargo.toml
      ./Cargo.lock
      ./src
    ];
  };
  cargoLock.lockFile = ./Cargo.lock;
  meta = {
    description = "System information utility (battery, backlight)";
    license = lib.licenses.mit;
    mainProgram = "sys";
  };
}
