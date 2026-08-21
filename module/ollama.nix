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
  json = pkgs.formats.json { };

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

  jobJson = json.generate "ollama.json" {
    Job = {
      ID = "ollama";
      Name = "ollama";
      Type = "service";
      Datacenters = [ "home" ];

      TaskGroups = [
        {
          Name = "ollama";
          Count = 1;

          Constraints = [
            {
              LTarget = "\${meta.pi_worker}";
              RTarget = "true";
              Operand = "=";
            }
          ]
          ++ lib.optional (cfg.nodeAddress != null) {
            LTarget = "\${attr.unique.network.ip-address}";
            RTarget = cfg.nodeAddress;
            Operand = "=";
          };

          Volumes.ollama = {
            Name = "ollama";
            Type = "host";
            Source = "ollama";
            ReadOnly = false;
          };

          Tasks = [
            {
              Name = "ollama";
              Driver = "podman";

              Config = {
                image = cfg.image;
                network_mode = "host";
                entrypoint = [
                  "/bin/sh"
                  "/opt/ollama-entrypoint.sh"
                ];
                volumes = [ "${entrypoint}:/opt/ollama-entrypoint.sh:ro" ];
              };

              VolumeMounts = [
                {
                  Volume = "ollama";
                  Destination = "/root/.ollama";
                  ReadOnly = false;
                }
              ];

              Env = {
                OLLAMA_CONTEXT_LENGTH = toString cfg.contextLength;
                OLLAMA_HOST = "0.0.0.0:${toString cfg.port}";
                OLLAMA_KEEP_ALIVE = "-1";
                OLLAMA_MAX_LOADED_MODELS = "1";
                OLLAMA_MODELS = "/root/.ollama/models";
                OLLAMA_NUM_PARALLEL = "1";
              };

              Resources = {
                CPU = cfg.cpu;
                MemoryMB = cfg.memoryMB;
              };
            }
          ];
        }
      ];
    };
  };
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
      description = "Host path backing the Nomad Ollama volume.";
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
    services.nomad.settings.client.host_volume.ollama = {
      path = cfg.stateDir;
      read_only = false;
    };

    systemd.tmpfiles.rules = [ "d ${cfg.stateDir} 0750 root root - -" ];

    systemd.services.ollama-job-register = {
      description = "Register the Ollama Nomad job";
      after = [ "nomad-acl-bootstrap.service" ];
      requires = [ "nomad-acl-bootstrap.service" ];
      wantedBy = [ "multi-user.target" ];
      environment.NOMAD_ADDR = "http://127.0.0.1:4646";
      path = with pkgs; [
        curl
        coreutils
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -u
        umask 077
        tmp=$(mktemp)
        trap 'rm -f "$tmp"' EXIT
        tr -d '[:space:]' < ${config.sops.secrets."nomad/bootstrap_token".path} > "$tmp"
        token=$(cat "$tmp")

        for _ in $(seq 1 60); do
          code=$(curl -s -o /dev/null -w '%{http_code}' \
            -H "X-Nomad-Token: $token" \
            -X POST "$NOMAD_ADDR/v1/jobs" \
            --data @${jobJson}) || code=000
          case "$code" in
            200)
              echo "ollama job registered"
              exit 0
              ;;
            *)
              sleep 2
              ;;
          esac
        done
        echo "ollama job registration failed after retries" >&2
        exit 1
      '';
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
