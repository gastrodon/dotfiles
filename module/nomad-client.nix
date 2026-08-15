# Nomad client — worker node, joins server.local via mDNS, podman driver (no docker).
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
      # both needed: extraPackages puts podman on PATH, extraSettingsPlugins puts the driver in -plugin-dir.
      extraPackages = [ pkgs.podman ];
      extraSettingsPlugins = [ pkgs.nomad-driver-podman ];

      settings = {
        region = "global";
        datacenter = cfg.datacenter;

        server.enabled = false;

        client = {
          enabled = true;
          # retry_join re-resolves DNS forever (recovers if it boots before server.local resolves); a plain `servers` list resolves once then drops.
          server_join.retry_join = cfg.serverAddrs;
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
