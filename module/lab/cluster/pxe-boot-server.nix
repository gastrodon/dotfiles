# PXE proxy-DHCP boot server (stone → the generic server boxes). Transport only:
# the netboot payload is staged into payloadDir out of band, so this host never
# drags the target closure into its store. One-stage iPXE (embedded chain script).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.pxeBootServer;

  # iPXE with chain script baked in; builds both ipxe.efi (UEFI) + undionly.kpxe (BIOS), dnsmasq picks per client arch.
  ipxe = pkgs.ipxe.override {
    embedScript = pkgs.writeText "pxe-chain.ipxe" ''
      #!ipxe
      dhcp
      chain http://${cfg.hostAddress}:${toString cfg.httpPort}/netboot.ipxe
    '';
  };
in
{
  options.services.pxeBootServer = {
    enable = lib.mkEnableOption "LAN PXE proxy-DHCP boot server";

    interface = lib.mkOption {
      type = lib.types.str;
      description = "LAN interface to serve PXE on.";
    };

    hostAddress = lib.mkOption {
      type = lib.types.str;
      description = "This host's stable LAN IPv4 (the HTTP chain target).";
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port nginx serves the netboot payload on.";
    };

    payloadDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/pxe";
      description = "Directory nginx serves; netboot payload is staged here.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.dnsmasq = {
      enable = true;
      # Don't register dnsmasq as the resolver: port=0 means no DNS listener, so it'd break all host name resolution.
      resolveLocalQueries = false;
      settings = {
        port = 0; # DNS off — boot helper, not a resolver
        interface = cfg.interface;
        bind-interfaces = true;

        # proxy mode: coexist with router DHCP, answer PXE only
        dhcp-range = [ "${cfg.hostAddress},proxy" ];

        enable-tftp = true;
        tftp-root = "${ipxe}";

        pxe-service = [
          "x86PC,iPXE (BIOS),undionly.kpxe"
          "x86-64_EFI,iPXE (UEFI),ipxe.efi"
        ];

        log-dhcp = true; # PXEClient DISCOVERs visible via journalctl -u dnsmasq -f
      };
    };

    services.nginx = {
      enable = true;
      virtualHosts."pxe" = {
        listen = [
          {
            addr = "0.0.0.0";
            port = cfg.httpPort;
          }
        ];
        root = cfg.payloadDir;
        locations."/".extraConfig = "autoindex on;";
      };
    };

    # 0775 claude:users so claude/eva can stage the payload without sudo
    systemd.tmpfiles.rules = [ "d ${cfg.payloadDir} 0775 claude users - -" ];

    networking.firewall.allowedUDPPorts = [
      67
      69
      4011
    ];
    networking.firewall.allowedTCPPorts = [ cfg.httpPort ];
  };
}
