final: _prev: {
  sys = final.callPackage ./sys/package.nix { };
  rend = final.callPackage ./rend/package.nix { };
  tpm-client-cert = final.callPackage ./tpm-client-cert.nix { };
  claude-config-merge = final.callPackage ./claude-config-merge { };
}
