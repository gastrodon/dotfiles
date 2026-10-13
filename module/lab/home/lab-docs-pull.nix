{ hostname, lib, ... }:
{
  # Keeps /srv/code/lab/docs (global.md, atlas.md behind the CLAUDE.md symlinks) current.
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
