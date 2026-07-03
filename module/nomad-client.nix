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
      extraPackages = [
        pkgs.podman
        pkgs.nomad-driver-podman
      ];

      settings = {
        region = "global";
        datacenter = cfg.datacenter;

        server.enabled = false;

        client = {
          enabled = true;
          servers = cfg.serverAddrs;
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
