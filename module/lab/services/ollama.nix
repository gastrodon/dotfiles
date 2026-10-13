# This module no longer defines the Nomad job (spec moved to
# ~/code/home-infra/infra/ollama.nomad.hcl) — only the firewall port and
# state directory with correct ownership remain here. `enable = false` also
# drops those, not just an already-nonexistent job. See wiki:
# Job-registration split
# (https://linear.app/gastrodon/document/job-registration-split-firewallstate-dir-only-modules-91e3fa6c89ae).
#
# Ollama as a Nomad service job. The host only provides Nomad, Podman, and a
# persistent host volume; the model server and its models live in the job.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.ollamaJob;

  entrypoint = pkgs.writeText "ollama-entrypoint.sh" ''
    set -eu

    ollama serve &
    server_pid=$!

    cleanup() {
      kill "$server_pid" 2>/dev/null || true
      wait "$server_pid" 2>/dev/null || true
    }
    trap cleanup TERM INT

    until ollama list >/dev/null 2>&1; do
      if ! kill -0 "$server_pid" 2>/dev/null; then
        exit 1
      fi
      sleep 1
    done

    ${lib.concatMapStringsSep "\n" (model: "ollama pull ${lib.escapeShellArg model}") cfg.models}

    wait "$server_pid"
  '';

  in
{
  options.services.ollamaJob = {
    enable = lib.mkEnableOption "Ollama as a Nomad service job";

    image = lib.mkOption {
      type = lib.types.str;
      default = "docker://ollama/ollama:latest";
      description = "Container image for the CPU-only Ollama service.";
    };

    models = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Models pulled into the persistent Ollama volume before serving.";
    };

    nodeAddress = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional Nomad client IP to pin the host-networked service to.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/ollama";
      description = "Host path bind-mounted as /root/.ollama by infra/ollama.nomad.hcl.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 11434;
      description = "Host-network port exposed by Ollama.";
    };

    contextLength = lib.mkOption {
      type = lib.types.ints.positive;
      default = 8192;
      description = "Default context length passed to Ollama.";
    };

    cpu = lib.mkOption {
      type = lib.types.ints.positive;
      default = 6000;
      description = "Nomad CPU reservation in MHz.";
    };

    memoryMB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 8192;
      description = "Nomad memory reservation in MB.";
    };
  };

  config = lib.mkIf cfg.enable {
    # host_volume.ollama removed (EVA-302) — nomad-storage.nix owns it now.
    systemd.tmpfiles.rules = [ "d ${cfg.stateDir} 0750 root root - -" ];

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
