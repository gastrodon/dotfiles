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

        # RETRY, BECAUSE THE SERVE CONFIG IS SHARED MUTABLE STATE.
        #
        # `tailscale funnel` and `tailscale serve` both read-modify-write one
        # per-node serve config, guarded by an etag. Any other unit doing the
        # same thing concurrently loses with:
        #
        #   Another client is changing the serve config; please try again.
        #   sending serve config: Preconditions failed: etag mismatch
        #
        # This is not hypothetical: module/testbench-web.nix installs a second
        # funnel unit, both are wantedBy multi-user.target, and systemd starts
        # them in parallel — so on any given boot one of the two mappings could
        # silently fail to apply. It was caught after a reboot left the Linear
        # webhook's 443 mapping missing while testbench's 8443 mapping was fine.
        #
        # Ordering alone would not be enough (anything else touching the config
        # races too), so retry on the conflict rather than only sequencing.
        for attempt in $(seq 1 10); do
          if out=$(timeout 15 tailscale funnel --bg ${cfg.target} 2>&1); then
            exit 0
          fi
          case "$out" in
            *"etag mismatch"* | *"Another client is changing"*)
              sleep 2
              ;;
            *)
              # A real failure, and NOT necessarily an ACL problem — the old
              # message asserted that and sent at least one investigation down
              # the wrong path. Print what actually happened and let the reader
              # decide.
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
