# The vault lives in Trilium (doc.lab.gastrodon.io); lab/docs keeps only house rules and the generated atlas.
# TRILIUM_MCP_TOKEN feeds the `trilium` MCP header in claude.nix; fetched at shell start like LINEAR_API_KEY.
{
  hostname,
  lib,
  pkgs,
  ...
}:
let
  baoKvGetCached = import ./bao-kv-get-cached.nix { inherit pkgs; };
in
{
  programs.zsh.initContent = lib.mkOrder 550 ''
    TRILIUM_MCP_TOKEN="$(${baoKvGetCached}/bin/bao-kv-get-cached claude/trilium token 2>/dev/null)" \
      && export TRILIUM_MCP_TOKEN
  '';

  # Keeps /srv/code/lab/docs (global.md, atlas.md behind the CLAUDE.md symlinks) current now that obsidian-git doesn't.
  systemd.user.services.lab-docs-pull = lib.mkIf (hostname == "stone") {
    Unit.Description = "Fast-forward /srv/code/lab/docs from Gitea";
    Service = {
      Type = "oneshot";
      Environment = [ "PATH=/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin" ];
      ExecStart = "/run/current-system/sw/bin/git -C /srv/code/lab/docs pull -q --ff-only";
    };
  };

  systemd.user.timers.lab-docs-pull = lib.mkIf (hostname == "stone") {
    Unit.Description = "Keep /srv/code/lab/docs current";
    Timer = {
      OnCalendar = "*:0/10";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
