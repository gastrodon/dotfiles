{ pkgs, lib, ... }:
let
  cmd = import ./cmd { inherit pkgs lib; };
  sys = import ./sys { inherit pkgs lib; };
in
{
  pkgs = builtins.attrValues cmd ++ [ sys ];
  inherit
    cmd
    sys
    ;
}
