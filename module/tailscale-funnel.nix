# Tailscale Funnel: exposes a loopback port publicly over HTTPS at
# https://<node>.<tailnet>.ts.net, no inbound port-forward. Fronts the Linear
# webhook receiver. Auth key + Funnel-enable in the tailnet ACL are one-time
# admin-console steps; everything below is declarative.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.tailscaleFunnel;
in
{
  options.services.tailscaleFunnel = {
    enable = lib.mkEnableOption "Tailscale Funnel fronting a local port";

    target = lib.mkOption {
      type = lib.types.str;
      default = "3456";
      description = "Local target funnel proxies to — a port, or proto:port. Public side is always HTTPS 443.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      openFirewall = true;
      authKeyFile = config.sops.secrets."tailscale/auth_key".path;
      # Funnel needs a fetched TLS cert; the node must be reachable and MagicDNS/HTTPS on.
      extraSetFlags = [ "--ssh=false" ];
    };

    sops.secrets."tailscale/auth_key" = {
      sopsFile = ../secrets.claude.yaml;
      format = "yaml";
    };

    # Apply the funnel mapping once tailscaled is authed. Idempotent re-apply.
    systemd.services.tailscale-funnel = {
      description = "Expose ${cfg.target} via Tailscale Funnel";
      after = [
        "tailscaled.service"
        "tailscaled-autoconnect.service"
        "network-online.target"
      ];
      requires = [ "tailscaled.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.tailscale ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -eu
        # Wait for the node to be Running before serving.
        for _ in $(seq 1 30); do
          if tailscale status --json 2>/dev/null | grep -q '"BackendState": *"Running"'; then
            break
          fi
          sleep 2
        done
        tailscale funnel --bg ${cfg.target}
      '';
    };
  };
}
