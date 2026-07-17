{ pkgs, lib }:
# TypeScript-authored MCP server compiled to a single Rhino-compatible JS
# bundle. The output is one file, mcp_server.js, meant to be symlinked into
# a KubeJS server_scripts/ directory. See README.md for the interface and
# CLAUDE.md for Rhino/KubeJS authoring constraints.
pkgs.stdenvNoCC.mkDerivation {
  pname = "mcp-kubejs";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [
    pkgs.esbuild
    pkgs.typescript
  ];

  buildPhase = ''
    runHook preBuild

    # Type-check first; esbuild strips types without checking them.
    tsc --noEmit -p tsconfig.json

    # Single IIFE bundle at es2015: KubeJS's Rhino fork handles ES2015-ish
    # syntax but has no module loader and no event loop. esbuild lowers
    # optional chaining / nullish coalescing; we avoid async entirely.
    esbuild src/main.ts \
      --bundle \
      --format=iife \
      --target=es2015 \
      --outfile=mcp_server.js

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp mcp_server.js $out/
    runHook postInstall
  '';
}
