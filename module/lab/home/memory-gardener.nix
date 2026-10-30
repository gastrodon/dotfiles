# Memory gardener (Trilium decision note 2026-09-27-memory-gardener): the
# lab/pkgs driver runs the `gardener` agent nightly over Claude Code
# auto-memory; by hand the agent only reports.
{
  hostname,
  lib,
  pkgs,
  ...
}:
let
  env = [ "PATH=/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin" ];
  flake = "git+https://git.lab.gastrodon.io/lab/pkgs.git";
  garden = pkgs.writeShellApplication {
    name = "memory-gardener";
    runtimeInputs = [
      pkgs.nix
      pkgs.coreutils
    ];
    text = ''
      out=$(nix build --refresh --no-link --print-out-paths "${flake}#memory-gardener")
      mkdir -p "$HOME/.claude/agents"
      rm -f "$HOME/.claude/agents/gardener.md"
      install -m644 "$out/share/memory-gardener/gardener.md" "$HOME/.claude/agents/gardener.md"
      exec "$out/bin/memory-gardener" "$@"
    '';
  };
in
lib.mkIf (hostname == "stone") {
  home.packages = [ garden ];

  systemd.user.services.memory-gardener = {
    Unit = {
      Description = "Drain Claude Code auto-memory into Trilium, repo CLAUDE.md, Gitea and Plane";
      Documentation = "https://doc.lab.gastrodon.io/#root/N6tQyPn58vEg";
      OnFailure = "memory-gardener-alert.service";
    };
    Service = {
      Type = "oneshot";
      Environment = env ++ [ "CLAUDE_CODE_DISABLE_AUTO_MEMORY=1" ];
      WorkingDirectory = "%h";
      ExecStart = "${lib.getExe garden} run";
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
      ExecStart = "${lib.getExe garden} alert --unit memory-gardener.service";
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

  xdg.configFile =
    lib.genAttrs
      [
        "systemd/user/memory-gardener.service"
        "systemd/user/memory-gardener-alert.service"
        "systemd/user/memory-gardener.timer"
        "systemd/user/timers.target.wants/memory-gardener.timer"
      ]
      (_: {
        force = true;
      });
}
