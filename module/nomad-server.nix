# Nomad server — HA raft peer. Every server box runs this; they form one cluster.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  hosts = import ./hosts.nix;
  serverIps = lib.attrValues (lib.filterAttrs (n: _: lib.hasPrefix "server" n) hosts);
  # Server-to-server join is serf gossip on 4648 — NOT the RPC port 4647 (that's
  # what clients use to reach servers). Joining on 4647 never forms gossip, so
  # each server bootstraps its own raft → split brain.
  serverGossipAddrs = map (ip: "${ip}:4648") serverIps;
in
{
  services.nomad = {
    enable = true;
    package = pkgs.nomad;
    dropPrivileges = false;
    enableDocker = false;
    # both needed: extraPackages puts podman on PATH, extraSettingsPlugins puts the driver in -plugin-dir.
    extraPackages = [ pkgs.podman ];
    extraSettingsPlugins = [ pkgs.nomad-driver-podman ];

    settings = {
      region = "global";
      datacenter = "home";

      acl.enabled = true;

      server = {
        enabled = true;
        bootstrap_expect = builtins.length serverGossipAddrs;
        # Same list on every box; a peer self-joining is a no-op.
        server_join.retry_join = serverGossipAddrs;

        # Preemption lets higher-priority jobs reclaim resources from lower-priority
        # ones. Needed so batch compute (e.g. the decomp workload in the `decomp`
        # namespace, priority 10) can use the whole cluster without risking that a
        # real service — home-assistant, mysql, traefik — fails to place after a
        # node reboot or a `nixos-rebuild --target-host` deploy.
        #
        # NOTE: default_scheduler_config only applies at INITIAL raft bootstrap.
        # On an already-bootstrapped cluster it is inert, which is why the
        # nomad-scheduler-config service below also applies it at runtime. Both
        # exist on purpose: this block is the declarative intent for a fresh
        # cluster, that service is what actually converges the running one.
        default_scheduler_config = {
          preemption_config = {
            system_scheduler_enabled = true;
            service_scheduler_enabled = true;
            batch_scheduler_enabled = true;
            sysbatch_scheduler_enabled = true;
          };
        };
      };

      # Co-located client — reaches the local server over loopback, no retry_join needed.
      # pi_worker meta pins the pi-agent job here (only server boxes carry the piPkg store path + auth volume).
      client = {
        # THE ARTIFACT/LANDLOCK FIX (EVA-324).
        #
        # Nomad re-execs itself as `nomad artifact-isolation` and confines the
        # download with landlock. The rule set is built from PATHS, and on
        # NixOS /etc/ssl/certs/ca-certificates.crt is a SYMLINK into
        # /nix/store — a File rule does not follow it, so the getter opens the
        # link, lands outside the sandbox, and every artifact fetch dies with:
        #
        #   x509: failed to load system roots and no roots provided;
        #   open /etc/ssl/certs/ca-certificates.crt: permission denied
        #
        # One read grant on one file. Landlock stays on.
        #
        # NOT `disable_filesystem_isolation = true`, which also works and turns
        # the entire sandbox off for a problem that is one missing read grant
        # wide. home-infra/docs/decisions.md recorded that as "an actual fix"
        # for a while; it has been corrected.
        #
        # Verified against nomad 1.11.3 on this cluster by driving the
        # artifact-isolation subcommand directly: baseline FAILs with the x509
        # error above, this config PASSes. The intuitive alternative does NOT
        # work — setting SSL_CERT_FILE via set_environment_variables fails
        # identically, because the problem is the sandbox, not the lookup path.
        artifact.filesystem_isolation_extra_paths = [
          "f:r:/etc/ssl/certs/ca-certificates.crt"
        ];
        enabled = true;
        meta.pi_worker = "true";
      };

      plugin.nomad-driver-podman.config = {
        socket_path = "unix:///run/podman/podman.sock";
        volumes.enabled = true;
      };
    };
  };

  # Rootful podman socket for the Nomad podman driver.
  systemd.sockets.podman.wantedBy = [ "sockets.target" ];

  # Idempotent one-shot ACL bootstrap with the known sops management token ("already done" = success).
  systemd.services.nomad-acl-bootstrap = {
    description = "Bootstrap Nomad ACL with the known management token";
    after = [ "nomad.service" ];
    requires = [ "nomad.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.nomad ];
    environment.NOMAD_ADDR = "http://127.0.0.1:4646";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -u
      umask 077
      tmp=$(mktemp)
      trap 'rm -f "$tmp"' EXIT
      # Trim any trailing whitespace/newline so the token is a bare UUID.
      tr -d '[:space:]' < ${config.sops.secrets."nomad/bootstrap_token".path} > "$tmp"

      for _ in $(seq 1 60); do
        if out=$(nomad acl bootstrap "$tmp" 2>&1); then
          echo "nomad ACL bootstrapped"
          exit 0
        fi
        case "$out" in
          *"already done"*)
            echo "nomad ACL already bootstrapped"
            exit 0
            ;;
          *"No cluster leader"* | *"connection refused"* | *EOF*)
            sleep 2
            ;;
          *)
            echo "unexpected bootstrap error: $out" >&2
            sleep 2
            ;;
        esac
      done
      echo "nomad ACL bootstrap failed after retries" >&2
      exit 1
    '';
  };

  # Converge scheduler config on an already-bootstrapped cluster.
  #
  # server.default_scheduler_config above only takes effect at initial raft
  # bootstrap, so on a live cluster it does nothing. This applies the same
  # settings through the API, idempotently, the way nomad-acl-bootstrap does for
  # ACLs. Safe to run on every server: the write is convergent, and whichever
  # peer reaches the leader first wins with an identical payload.
  systemd.services.nomad-scheduler-config = {
    description = "Converge Nomad scheduler config (enable preemption)";
    after = [ "nomad-acl-bootstrap.service" ];
    requires = [ "nomad.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.nomad ];
    environment.NOMAD_ADDR = "http://127.0.0.1:4646";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -u
      umask 077
      # operator:write is required once ACLs are on, so reuse the management token.
      NOMAD_TOKEN=$(tr -d '[:space:]' < ${config.sops.secrets."nomad/bootstrap_token".path})
      export NOMAD_TOKEN

      for _ in $(seq 1 60); do
        if nomad operator scheduler set-config \
             -preempt-system-scheduler=true \
             -preempt-service-scheduler=true \
             -preempt-batch-scheduler=true \
             -preempt-sysbatch-scheduler=true; then
          echo "nomad scheduler config applied (preemption enabled)"
          exit 0
        fi
        sleep 2
      done
      echo "nomad scheduler config failed after retries" >&2
      exit 1
    '';
  };

  networking.firewall.allowedTCPPorts = [
    4646
    4647
    4648
  ];
  networking.firewall.allowedUDPPorts = [ 4648 ];
}
