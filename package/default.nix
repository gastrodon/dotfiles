{ pkgs, lib, ... }:
let
  cmdPackages = import ./cmd { inherit pkgs lib; };
  sysinfo = import ./sysinfo { inherit pkgs lib; };
in
{
  cmd = builtins.attrValues cmdPackages;
  pkgs = builtins.attrValues cmdPackages ++ [ sysinfo ];
  inherit sysinfo;
}
