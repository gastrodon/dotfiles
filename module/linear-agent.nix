# Linear agent-session webhook receiver. Verifies Linear's HMAC, acks the
# session with a `thought` activity, and dispatches a parameterized Nomad job
# (pi-agent) to run the actual work. The tunnel that fronts this is a separate
# concern — the receiver only binds loopback.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.linearAgent;
  linear-agent = import ../package/linear-agent { inherit pkgs lib; };
in
{
  options.services.linearAgent = {
    enable = lib.mkEnableOption "Linear agent webhook receiver";

    listenAddr = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:3456";
      description = "Host:port the receiver binds. Loopback — a tunnel fronts it.";
    };

    nomadJob = lib.mkOption {
      type = lib.types.str;
      default = "pi-agent";
      description = "Parameterized Nomad batch job dispatched per session.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.linear-agent = {
      isSystemUser = true;
      group = "linear-agent";
      description = "Linear agent webhook receiver";
    };
    users.groups.linear-agent = { };

    sops.secrets."linear/webhook_secret" = {
      sopsFile = ../secrets.claude.yaml;
      format = "yaml";
    };
    # The receiver bootstraps from the refresh token alone: on first use it mints
    # an access token (client_id/secret + refresh_token) and persists the rotated
    # material to StateDirectory, which is authoritative thereafter.
    sops.secrets."linear/refresh_token" = {
      sopsFile = ../secrets.claude.yaml;
      format = "yaml";
    };
    sops.secrets."linear/client_id" = {
      sopsFile = ../secrets.claude.yaml;
      format = "yaml";
    };
    sops.secrets."linear/client_secret" = {
      sopsFile = ../secrets.claude.yaml;
      format = "yaml";
    };

    # Env file assembled from secret placeholders; NOMAD_TOKEN reuses the
    # cluster management token already declared in module/sops.nix.
    sops.templates."linear-agent.env" = {
      owner = "linear-agent";
      content = ''
        LINEAR_WEBHOOK_SECRET=${config.sops.placeholder."linear/webhook_secret"}
        LINEAR_REFRESH_TOKEN=${config.sops.placeholder."linear/refresh_token"}
        LINEAR_CLIENT_ID=${config.sops.placeholder."linear/client_id"}
        LINEAR_CLIENT_SECRET=${config.sops.placeholder."linear/client_secret"}
        NOMAD_TOKEN=${config.sops.placeholder."nomad/bootstrap_token"}
      '';
    };

    systemd.services.linear-agent = {
      description = "Linear agent-session webhook receiver";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        LISTEN_ADDR = cfg.listenAddr;
        NOMAD_ADDR = "http://127.0.0.1:4646";
        NOMAD_JOB = cfg.nomadJob;
        STATE_DIR = "/var/lib/linear-agent";
      };
      serviceConfig = {
        ExecStart = "${linear-agent}/bin/linear-agent";
        EnvironmentFile = config.sops.templates."linear-agent.env".path;
        User = "linear-agent";
        Group = "linear-agent";
        Restart = "always";
        RestartSec = 5;
        # /var/lib/linear-agent, owned by the service user — holds the rotated
        # OAuth token state; stays writable under ProtectSystem=strict.
        StateDirectory = "linear-agent";
        StateDirectoryMode = "0700";
        # Hardening — network service; only writes are to StateDirectory.
        DynamicUser = false;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
    };
  };
}
