# Nomad server — sole cluster leader. Single-server, no HA.
# Also runs a co-located client (datacenter `home`) so the box can run jobs
# itself, not just schedule them onto stone/the RPis.
{ config, pkgs, ... }:
{
  services.nomad = {
    enable = true;
    package = pkgs.nomad;
    dropPrivileges = false;
    enableDocker = false;
    extraPackages = [
      pkgs.podman
      pkgs.nomad-driver-podman
    ];

    settings = {
      region = "global";
      datacenter = "home";

      acl.enabled = true;

      server = {
        enabled = true;
        bootstrap_expect = 1;
      };

      # Co-located client. It reaches the local server over loopback RPC, so no
      # server list / retry_join is needed here.
      client.enabled = true;

      plugin.nomad-driver-podman.config = {
        socket_path = "unix:///run/podman/podman.sock";
        volumes.enabled = true;
      };
    };
  };

  # Rootful podman socket for the Nomad podman driver.
  systemd.sockets.podman.wantedBy = [ "sockets.target" ];

  # One-shot ACL bootstrap with our known management token (from sops). ACL
  # bootstrap is a one-time raft-state operation, so this is idempotent:
  # "already been bootstrapped" is treated as success. Runs as root, which can
  # read the token regardless of its ownership.
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
          *"already been bootstrapped"*)
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
