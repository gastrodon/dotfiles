# NOTE: THIS MODULE NO LONGER DEFINES THE NOMAD JOB.
#
# The job spec moved to ~/code/home-infra/testbench/testbench-web.nomad.hcl. What is left here is the
# host-level half that a container cannot do for itself: the firewall port, the
# state directory with correct ownership, and the host-volume declaration.
#
# The job JSON and the `testbench-web-job-register` oneshot that used to POST it at
# activation were removed deliberately. That unit ran on every boot and rebuild
# and re-POSTed the module's own spec under the same job ID, so leaving it in
# place while the spec also lived in home-infra would have meant two sources of
# truth with the stale one winning on every reboot.
#
# Keep this module ENABLED. `enable = false` would take the firewall rule and
# the tmpfiles rule with it, and the job would then run with no reachable port
# and no directory to mount.
#
# The testbench 3D viewer, as a Nomad service job.
#
# The page itself is built in the OTHER repo (gastrodon/testbench,
# `nix build .#viewer-site`) and pushed here with `nix run .#deploy`. This
# module owns only the things a page cannot own: a directory to land in, a
# web server in front of it, and a hole in the firewall.
#
# THE JOB IS CONTENT-FREE, and that is the whole design. It bind-mounts a
# directory and serves whatever it finds, so publishing a new model is an
# rsync into that directory -- not a job update, not a nixos-rebuild, and
# not a service restart. The alternative (baking the page into a store
# path the job mounts) would make every picture a full rebuild of this
# host, which is exactly the loop that repo's README says the flake is not
# meant to replace.
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
        already taken by module/tailscale-funnel.nix, which mounts the
        Linear webhook receiver at `/` — so use **8443** unless you
        deliberately want to share the host and mount this under a path.

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

    # Same idempotent register-over-the-API pattern as module/ollama.nix:
    # a job that is already registered comes back 200 and this is a no-op.
        networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    # Public exposure, declared so it survives a rebuild rather than
    # living in whatever `tailscale funnel` somebody typed once. Separate
    # from module/tailscale-funnel.nix on purpose: that module is
    # single-target and owns 443 for the Linear webhook, and folding a
    # second target into it would make one option mean two things.
    #
    # No firewall rule belongs here. Funnel traffic arrives through
    # tailscaled and reaches nginx over loopback, so the LAN port and the
    # public port are genuinely independent switches.
    systemd.services.testbench-web-funnel = lib.mkIf (cfg.funnelPort != null) {
      description = "Expose the testbench viewer publicly over Tailscale Funnel";
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
        if ! timeout 15 tailscale funnel --bg \
             --https=${toString cfg.funnelPort} \
             http://127.0.0.1:${toString cfg.port}; then
          echo "funnel not applied — is Funnel enabled for this node in the tailnet ACL?" >&2
        fi
        exit 0
      '';
    };
  };
}
