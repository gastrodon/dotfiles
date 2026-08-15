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
    sops.secrets."linear/app_token" = {
      sopsFile = ../secrets.claude.yaml;
      format = "yaml";
    };

    # Env file assembled from secret placeholders; NOMAD_TOKEN reuses the
    # cluster management token already declared in module/sops.nix.
    sops.templates."linear-agent.env" = {
      owner = "linear-agent";
      content = ''
        LINEAR_WEBHOOK_SECRET=${config.sops.placeholder."linear/webhook_secret"}
        LINEAR_APP_TOKEN=${config.sops.placeholder."linear/app_token"}
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
      };
      serviceConfig = {
        ExecStart = "${linear-agent}/bin/linear-agent";
        EnvironmentFile = config.sops.templates."linear-agent.env".path;
        User = "linear-agent";
        Group = "linear-agent";
        Restart = "always";
        RestartSec = 5;
        # Hardening — pure network service, no filesystem writes.
        DynamicUser = false;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
    };
  };
}
