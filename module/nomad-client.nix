# Nomad client — worker node, retry_joins the server boxes by IP, podman driver (no docker).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.nomadClient;
  hosts = import ./hosts.nix;
  serverIps = lib.attrValues (lib.filterAttrs (n: _: lib.hasPrefix "server" n) hosts);
in
{
  options.services.nomadClient = {
    datacenter = lib.mkOption {
      type = lib.types.str;
      default = "home";
      description = "Nomad datacenter this client registers into.";
    };

    serverAddrs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = map (ip: "${ip}:4647") serverIps;
      description = "Nomad server RPC addresses.";
    };
  };

  config = {
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
        datacenter = cfg.datacenter;

        # Must match the servers (module/nomad-server.nix). A client left with
        # ACLs disabled against ACL-enabled servers can still serve its own HTTP
        # API and forward UI requests, but every node RPC it makes is rejected —
        # Node.UpdateStatus and Node.GetClientAllocs come back "Permission
        # denied", so the node never registers and never appears in the topology.
        acl.enabled = true;

        server.enabled = false;

        client = {
          enabled = true;
          # retry_join re-resolves DNS forever (recovers if it boots before server.local resolves); a plain `servers` list resolves once then drops.
          server_join.retry_join = cfg.serverAddrs;
          # Declared, not merely absent: the pi-agent job selects nodes on
          # meta.pi_worker, and these clients must never win one. They carry
          # neither the worker's auth volume nor its store paths, and the rpi is
          # arm64 while the worker image is x86_64-only. Setting it false says so
          # in the config and in `nomad node status -verbose`, rather than
          # leaving the exclusion to depend on nobody ever adding the meta.
          meta.pi_worker = "false";
        };

        # No Consul here — disable auto-join to stop 127.0.0.1:8500 error spam.
        consul = {
          client_auto_join = false;
          server_auto_join = false;
        };

        plugin.nomad-driver-podman.config = {
          socket_path = "unix:///run/podman/podman.sock";
          volumes.enabled = true;
        };
      };
    };

    # Rootful podman socket for the Nomad podman driver.
    systemd.sockets.podman.wantedBy = [ "sockets.target" ];

    networking.firewall.allowedTCPPorts = [
      4646
      4647
      4648
    ];
    networking.firewall.allowedUDPPorts = [ 4648 ];
  };
}
