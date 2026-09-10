# NOTE: THIS MODULE NO LONGER DEFINES THE NOMAD JOB.
#
# The job spec moved to ~/code/home-infra/infra/ollama.nomad.hcl. What is left here is the
# host-level half that a container cannot do for itself: the firewall port, the
# state directory with correct ownership, and the host-volume declaration.
#
# The job JSON and the `ollama-job-register` oneshot that used to POST it at
# activation were removed deliberately. That unit ran on every boot and rebuild
# and re-POSTed the module's own spec under the same job ID, so leaving it in
# place while the spec also lived in home-infra would have meant two sources of
# truth with the stale one winning on every reboot.
#
# Keep this module ENABLED. `enable = false` would take the firewall rule and
# the tmpfiles rule with it, and the job would then run with no reachable port
# and no directory to mount.
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
    # NO `services.nomad.settings.client.host_volume.ollama` HERE ANY MORE —
    # module/nomad-storage.nix owns host volumes now, and publishes this one as
    # /data/volumes/ollama. See the equivalent note in module/home-assistant.nix
    # for why the old declaration had to be removed in the same change rather
    # than repointed: it declared the volume unconditionally, including on a
    # netbooted node where ${cfg.stateDir} is tmpfs.
    #
    # The tmpfiles rule stays: infra/ollama.nomad.hcl still bind-mounts
    # ${cfg.stateDir} directly.
    systemd.tmpfiles.rules = [ "d ${cfg.stateDir} 0750 root root - -" ];

        networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
