{ pkgs, lib, ... }:
rec {
  cmd = import ./cmd { inherit pkgs lib; };
  sys = import ./sys { inherit pkgs lib; };
  rend = import ./rend { inherit pkgs lib; };
  web = import ./web { inherit pkgs lib; };
  packages = builtins.attrValues cmd ++ [
    sys
    rend
    web
  ];
}
