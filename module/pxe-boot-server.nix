# PXE boot server — turns a host (stone) into the LAN netboot source for the
# generic server boxes. Proxy-DHCP only: it never hands out leases (the router
# stays the DHCP authority) — it just answers PXEClient requests alongside the
# router with a boot filename, so enabling it can't disrupt normal LAN DHCP.
#
# One-stage iPXE: the TFTP-served binary has its boot script embedded
# (embedScript), so it DHCPs once and chains straight to the HTTP payload —
# no re-served iPXE loop, hence no user-class tag dance.
#
# Transport only. The netboot payload itself (kernel/initrd/netboot.ipxe) is
# staged into payloadDir out of band (its bake-vs-thin shape depends on the
# target boxes' RAM), so rebuilding this host doesn't drag the target closure
# into its store.
#
# Callers set:
#   services.pxeBootServer.enable       — turn the host into a boot server
#   services.pxeBootServer.interface    — LAN NIC to serve on (e.g. "enp7s0")
#   services.pxeBootServer.hostAddress  — this host's stable LAN IPv4
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.pxeBootServer;

  # iPXE with the chain script baked in. Built for both firmware types:
  # ipxe.efi (UEFI) and undionly.kpxe (legacy BIOS) both land in the output,
  # and dnsmasq hands out the right one per client architecture.
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
      settings = {
        # DNS off — this is a boot helper, not a resolver.
        port = 0;
        interface = cfg.interface;
        bind-interfaces = true;

        # Proxy mode: coexist with the router's DHCP, answer PXE only.
        dhcp-range = [ "${cfg.hostAddress},proxy" ];

        enable-tftp = true;
        tftp-root = "${ipxe}";

        # Per client-arch boot filename (relative to tftp-root).
        pxe-service = [
          "x86PC,iPXE (BIOS),undionly.kpxe"
          "x86-64_EFI,iPXE (UEFI),ipxe.efi"
        ];

        # Surface PXEClient DISCOVERs in the journal so a boot attempt is
        # visible via `journalctl -u dnsmasq -f`.
        log-dhcp = true;
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

    # claude-owned, group-writable so the payload can be staged (by claude, or
    # by eva who shares the users group) without sudo.
    systemd.tmpfiles.rules = [ "d ${cfg.payloadDir} 0775 claude users - -" ];

    networking.firewall.allowedUDPPorts = [
      67
      69
      4011
    ];
    networking.firewall.allowedTCPPorts = [ cfg.httpPort ];
  };
}
