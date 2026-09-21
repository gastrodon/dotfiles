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

        # Two independent funnel units (this one + testbench-web.nix) both race
        # the same etag-guarded serve config at boot — real incident 2026-09-06
        # left 443 unmapped. See wiki: Tailscale Funnel serve-config race
        # (https://linear.app/gastrodon/document/tailscale-funnel-the-serve-config-race-21d164239621).
        for attempt in $(seq 1 10); do
          if out=$(timeout 15 tailscale funnel --bg ${cfg.target} 2>&1); then
            exit 0
          fi
          case "$out" in
            *"etag mismatch"* | *"Another client is changing"*)
              sleep 2
              ;;
            *)
              echo "funnel not applied: $out" >&2
              echo "if this mentions Funnel not being enabled, grant it for this node in the tailnet ACL and restart this unit" >&2
              exit 0
              ;;
          esac
        done

        echo "funnel not applied after 10 attempts — serve config stayed contended: $out" >&2
        # Still exit clean: a failed funnel must not wedge a nixos-rebuild.
        exit 0
      '';
    };
  };
}
