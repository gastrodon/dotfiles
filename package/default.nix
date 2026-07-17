{ pkgs, lib, ... }:
rec {
  cmd = import ./cmd { inherit pkgs lib; };
  sys = import ./sys { inherit pkgs lib; };
  rend = import ./rend { inherit pkgs lib; };
  mcp-kubejs = import ./mcp-kubejs { inherit pkgs lib; };
  packages = builtins.attrValues cmd ++ [
    sys
    rend
  ];
}
