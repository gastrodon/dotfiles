# The vault lives in Trilium (doc.lab.gastrodon.io); lab/docs keeps only house rules and the generated atlas.
# TRILIUM_MCP_TOKEN feeds the `trilium` MCP header in claude.nix; fetched at shell start like LINEAR_API_KEY.
{
  lib,
  pkgs,
  ...
}:
let
  baoKvGetCached = import ../lab/home/bao-kv-get-cached.nix { inherit pkgs; };
in
{
  programs.zsh.initContent = lib.mkOrder 550 ''
    TRILIUM_MCP_TOKEN="$(${baoKvGetCached}/bin/bao-kv-get-cached claude/trilium token 2>/dev/null)" \
      && export TRILIUM_MCP_TOKEN
  '';
}
