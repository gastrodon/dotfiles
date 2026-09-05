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
  imports = [ ./tailscale.nix ];

  options.services.tailscaleFunnel = {
    enable = lib.mkEnableOption "Tailscale Funnel fronting a local port";

    target = lib.mkOption {
      type = lib.types.str;
      default = "3456";
      description = "Local target funnel proxies to — a port, or proto:port. Public side is always HTTPS 443.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscaleClient.enable = true;

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
      path = [
        pkgs.tailscale
        pkgs.coreutils
        pkgs.gnugrep
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # Never wedge activation — cap the whole unit.
        TimeoutStartSec = 60;
      };
      script = ''
        set -u
        # Wait for the node to be Running before serving.
        for _ in $(seq 1 20); do
          if tailscale status --json 2>/dev/null | grep -q '"BackendState": *"Running"'; then
            break
          fi
          sleep 2
        done
        # If Funnel isn't yet enabled for this node in the tailnet ACL the CLI
        # blocks; bound it and exit clean so the switch completes. A later
        # `systemctl restart tailscale-funnel` (after the ACL grants funnel)
        # applies it for real.
        if ! timeout 15 tailscale funnel --bg ${cfg.target}; then
          echo "funnel not applied — is Funnel enabled for this node in the tailnet ACL?" >&2
        fi
        exit 0
      '';
    };
  };
}
