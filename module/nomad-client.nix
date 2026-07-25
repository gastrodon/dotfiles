# Nomad client — worker node. Connects to server.local via mDNS.
# Uses the podman task driver (no docker).
#
# Callers set:
#   services.nomadClient.datacenter — "home" (RPis) or "stone" (opt-in heavy)
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.nomadClient;
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
      default = [ "server.local:4647" ];
      description = "Nomad server RPC addresses.";
    };
  };

  config = {
    services.nomad = {
      enable = true;
      package = pkgs.nomad;
      dropPrivileges = false;
      enableDocker = false;
      # podman CLI must be on the agent's PATH; the driver binary must live in
      # nomad's -plugin-dir, which the module builds from extraSettingsPlugins
      # (NOT extraPackages — that only extends PATH).
      extraPackages = [ pkgs.podman ];
      extraSettingsPlugins = [ pkgs.nomad-driver-podman ];

      settings = {
        region = "global";
        datacenter = cfg.datacenter;

        server.enabled = false;

        client = {
          enabled = true;
          # retry_join re-resolves DNS names indefinitely, so the client
          # recovers if it boots before server.local is resolvable. A plain
          # `servers` list is resolved once at startup and silently dropped
          # on failure, leaving the client stuck falling back to Consul.
          server_join.retry_join = cfg.serverAddrs;
        };

        # No Consul in this cluster — disable auto-discovery so the client
        # doesn't spam errors trying to reach 127.0.0.1:8500.
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
