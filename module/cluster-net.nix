# Static IP on the LAN for cluster hosts that need a stable address
# (RPis — server and stone use router DHCP reservations instead).
#
# Callers set:
#   clusterNet.address — dotted-quad within 192.168.0.240/28 (the cluster block)
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
        DNS = [ "192.168.0.1" ];
        IPv6AcceptRA = true;
      };
    };
  };
}
