# Memory gardener (lab/docs decisions/2026-09-27-memory-gardener.md): drains
# Claude Code auto-memory into the vault nightly. The units were first written
# by hand on stone; force = true lets this replace them. A switch enables the
# timer, but a run happens only once ~/.local/state/memory-gardener/enabled
# exists, so a switch never turns the gardener on by itself.
{ hostname, lib, ... }:
let
  state = "%h/.local/state/memory-gardener";
  env = [ "PATH=/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin" ];
  refresh = ''/run/current-system/sw/bin/sh -c 'd=${state}/src; if [ -d "$$d/.git" ]; then git -C "$$d" fetch -q origin main && git -C "$$d" reset -q --hard origin/main; else git clone -q http://192.168.0.17:3000/lab/docs.git "$$d"; fi' '';
in
lib.mkIf (hostname == "stone") {
  systemd.user.services.memory-gardener = {
    Unit = {
      Description = "Drain Claude Code auto-memory into lab/docs, repo CLAUDE.md and Gitea issues";
      Documentation = "http://192.168.0.17:3000/lab/docs/src/branch/main/decisions/2026-09-27-memory-gardener.md";
      ConditionPathExists = "${state}/enabled";
      OnFailure = "memory-gardener-alert.service";
    };
    Service = {
      Type = "oneshot";
      Environment = env ++ [ "CLAUDE_CODE_DISABLE_AUTO_MEMORY=1" ];
      WorkingDirectory = "%h";
      ExecStartPre = lib.removeSuffix " " refresh;
      ExecStart = "/run/current-system/sw/bin/python3 ${state}/src/bin/garden.py run";
      TimeoutStartSec = "6h";
      Nice = 10;
    };
  };

  systemd.user.services.memory-gardener-alert = {
    Unit.Description = "Report a failed memory-gardener run as a Gitea issue on lab/docs";
    Service = {
      Type = "oneshot";
      Environment = env;
      WorkingDirectory = "%h";
      ExecStartPre = "-" + lib.removeSuffix " " refresh;
      ExecStart = "/run/current-system/sw/bin/python3 ${state}/src/bin/garden.py alert --unit memory-gardener.service";
    };
  };

  systemd.user.timers.memory-gardener = {
    Unit.Description = "Nightly memory gardener";
    Timer = {
      OnCalendar = "*-*-* 04:30:00";
      RandomizedDelaySec = "30m";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

  xdg.configFile = lib.genAttrs [
    "systemd/user/memory-gardener.service"
    "systemd/user/memory-gardener-alert.service"
    "systemd/user/memory-gardener.timer"
    "systemd/user/timers.target.wants/memory-gardener.timer"
  ] (_: { force = true; });
}
