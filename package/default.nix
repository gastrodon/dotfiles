{ pkgs, lib, ... }:
let
  cmd = import ./cmd { inherit pkgs lib; };
  sysinfo = import ./sysinfo { inherit pkgs lib; };
in
{
  pkgs = builtins.attrValues cmd ++ [ sysinfo ];
  inherit
    cmd
    sysinfo
    ;
}
