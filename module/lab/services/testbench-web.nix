# This module no longer defines the Nomad job (spec moved to
# ~/code/home-infra/testbench/testbench-web.nomad.hcl) — only the firewall
# port and state directory with correct ownership remain here.
# `enable = false` also drops the firewall/state-dir rules, not just an
# already-nonexistent job. See wiki: Job-registration split
# (https://linear.app/gastrodon/document/job-registration-split-firewallstate-dir-only-modules-91e3fa6c89ae).
#
# The testbench 3D viewer, as a Nomad service job. The page itself is built
# in the OTHER repo (gastrodon/testbench, `nix build .#viewer-site`) and
# pushed here with `nix run .#deploy`.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.testbenchWeb;

  in
{
  options.services.testbenchWeb = {
    enable = lib.mkEnableOption "the testbench 3D assembly viewer, served from Nomad";

    node = lib.mkOption {
      type = lib.types.str;
      default = "server1";
      description = ''
        Nomad client hostname the job is pinned to. Must be the host that
        carries stateDir — the content is a plain directory, not a
        replicated volume, so the job and the files have to be co-located.
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/eva/testbench-web";
      description = ''
        Directory the site is rsynced into and nginx serves out of. Under
        /home deliberately: `nix run .#deploy` pushes over SSH as an
        ordinary user, and a push that needs root is a push that will be
        done by hand instead.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8087;
      description = ''
        Port the page is served on. Declared here only to open the
        firewall — the number nginx actually listens on comes from the
        nginx.conf that ships with the content, and both are generated
        from one binding in the testbench flake.
      '';
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "docker://docker.io/library/nginx:alpine";
      description = "Container image for the static file server.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open `port` on the LAN. The page is not authenticated.";
    };

    funnelPort = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ 443 8443 10000 ]);
      default = null;
      description = ''
        Serve the page on the PUBLIC INTERNET over Tailscale Funnel, on
        this port. `null` (the default) means tailnet and LAN only.

        Funnel accepts only 443, 8443 and 10000. 443 on this host is
        already taken by module/tailscale-funnel.nix's Linear webhook, so
        this defaults to 8443.

        The page has no authentication of any kind. Anyone with the URL
        reads the models, the parameters and the stress numbers, and a
        public URL is a URL that gets crawled.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Exists before the job does, so nginx never starts against a missing
    # mount — podman would create it as a root-owned directory and the
    # first deploy would then fail on permissions.
    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir} 0755 eva users - -"
    ];

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    systemd.services.testbench-web-funnel = lib.mkIf (cfg.funnelPort != null) {
      description = "Expose the testbench viewer publicly over Tailscale Funnel";
      after = [
        "tailscaled.service"
        "tailscaled-autoconnect.service"
        "network-online.target"
        # `After` on a unit that does not exist on this host is simply ignored.
        "tailscale-funnel.service"
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
        # Never wedge activation, the same cap tailscale-funnel.nix uses.
        TimeoutStartSec = 60;
      };
      script = ''
        set -u
        for _ in $(seq 1 20); do
          if tailscale status --json 2>/dev/null | grep -q '"BackendState": *"Running"'; then
            break
          fi
          sleep 2
        done
        # See wiki: Tailscale Funnel serve-config race (also module/tailscale-funnel.nix)
        # (https://linear.app/gastrodon/document/tailscale-funnel-the-serve-config-race-21d164239621).
        for _ in $(seq 1 10); do
          if out=$(timeout 15 tailscale funnel --bg \
                   --https=${toString cfg.funnelPort} \
                   http://127.0.0.1:${toString cfg.port} 2>&1); then
            exit 0
          fi
          case "$out" in
            *"etag mismatch"* | *"Another client is changing"*)
              sleep 2
              ;;
            *)
              echo "funnel not applied: $out" >&2
              exit 0
              ;;
          esac
        done

        echo "funnel not applied after 10 attempts — serve config stayed contended: $out" >&2
        exit 0
      '';
    };
  };
}
