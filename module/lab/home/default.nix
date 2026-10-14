{ pkgs, lib, ... }:
{
  imports = [
    ./memory-gardener.nix
    ./lab-docs-pull.nix
  ];

  home.packages = [
    pkgs.bao-kv-get
    pkgs.bao-kv-get-cached
  ];

  home.sessionVariables.BAO_ADDR = "http://192.168.0.17:8200";

  # bao-kv-get-cached now caches on tmpfs ($XDG_RUNTIME_DIR); drop the old on-disk copies.
  home.activation.dropBaoKvGetDiskCache = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run rm -rf "''${XDG_CACHE_HOME:-$HOME/.cache}/bao-kv-get"
  '';
}
