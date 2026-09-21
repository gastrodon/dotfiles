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
        # On an already-bootstrapped cluster it's inert — converging a running
        # cluster is a one-time operator command now, not a service (see below).
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
        # landlock artifact-isolation needs an explicit read-grant for
        # /etc/ssl/certs/ca-certificates.crt (a symlink into /nix/store the
        # sandbox doesn't allowlist by default) — EVA-324.
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

  # ACL bootstrap and scheduler-config convergence are one-time operator
  # commands (home-infra/bin/bootstrap-acls, bin/converge-scheduler-config),
  # not per-boot oneshots, now that both live durably in Nomad's own Raft log
  # (EVA-302). See wiki: Nomad storage durability design.

  networking.firewall.allowedTCPPorts = [
    4646
    4647
    4648
  ];
  networking.firewall.allowedUDPPorts = [ 4648 ];
}
