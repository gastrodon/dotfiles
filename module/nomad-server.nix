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
      };

      # Co-located client — reaches the local server over loopback, no retry_join needed.
      # pi_worker meta pins the pi-agent job here (only server boxes carry the piPkg store path + auth volume).
      client = {
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

  networking.firewall.allowedTCPPorts = [
    4646
    4647
    4648
  ];
  networking.firewall.allowedUDPPorts = [ 4648 ];
}
