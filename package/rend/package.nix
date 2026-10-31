{ lib, rustPlatform }:
rustPlatform.buildRustPackage {
  pname = "rend";
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
    description = "Render numbers as text visualizations (bars)";
    license = lib.licenses.mit;
    mainProgram = "rend";
  };
}
