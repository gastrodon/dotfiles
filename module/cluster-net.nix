# Static LAN IP for cluster hosts (RPis) in the 192.168.0.240/28 block; server/stone use router DHCP reservations instead.
{
  config,
  lib,
  ...
}:
let
  cfg = config.clusterNet;
in
{
  options.clusterNet = {
    address = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Static LAN address (dotted-quad). Null disables.";
    };
  };

  config = lib.mkIf (cfg.address != null) {
    networking.useNetworkd = true;
    networking.useDHCP = false;

    systemd.network.enable = true;
    systemd.network.networks."10-cluster" = {
      matchConfig.Type = "ether";
      networkConfig = {
        Address = "${cfg.address}/24";
        Gateway = "192.168.0.1";
        DNS = [
          "1.1.1.1"
          "8.8.8.8"
        ];
        IPv6AcceptRA = true;
      };
    };
  };
}
