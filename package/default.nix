{ pkgs, lib, ... }:
rec {
  cmd = import ./cmd { inherit pkgs lib; };
  sys = import ./sys { inherit pkgs lib; };
  rend = import ./rend { inherit pkgs lib; };
  mcp-minecraft = import ./mcp-minecraft { inherit pkgs lib; };
  packages = builtins.attrValues cmd ++ [
    sys
    rend
    mcp-minecraft
  ];
}
