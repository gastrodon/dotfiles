# EC2-style hostname derived from the node's own LAN address (EVA-301, EVA-192).
# See wiki: Cluster hostname identity: DHCP-derived names vs NetworkManager.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Empty static hostname: there is deliberately no per-box name to fall back
  # to, so a misconfiguration shows up as an obviously wrong hostname rather
  # than as a box quietly answering to a name that belongs to a different
  # machine.
  networking.hostName = "";

  # Only meaningful where NetworkManager is actually running. The netbooted
  # cluster nodes do not import hosts/shared.nix and so have no NetworkManager
  # to call off — for them the unit alone has always been sufficient.
  networking.networkmanager.settings = lib.mkIf config.networking.networkmanager.enable {
    main.hostname-mode = "none";
  };

  systemd.services.derive-hostname = {
    description = "Set transient hostname from primary LAN IPv4";
    wantedBy = [ "multi-user.target" ];

    # Deliberately NOT network-online.target — nothing provides it on the
    # netboot image, so the unit would silently never run. See wiki: Cluster
    # hostname identity.
    after = [ "network.target" ];

    # Both of these read the hostname once, at startup, and never revisit it.
    # Nomad takes its node name from it — losing that race registers the node
    # under whatever transient name DHCP produced first — and tailscaled takes
    # its MagicDNS name from it, which is how a public URL ends up depending on
    # a DHCP lease (EVA-273).
    before = [
      "nomad.service"
      "tailscaled.service"
      "avahi-daemon.service"
    ];

    path = [
      pkgs.iproute2
      pkgs.gawk
      pkgs.systemd
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    # `ip route get` (not the first global-scope address) so a multi-homed box
    # names itself after the interface actually carrying traffic. Polls with a
    # 180s bound rather than assuming DHCP is already done. See wiki: Cluster
    # hostname identity.
    script = ''
      for _ in $(seq 1 180); do
        ip=$(ip -4 route get 1.1.1.1 2>/dev/null \
          | awk '{ for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit } }')
        if [ -n "$ip" ]; then
          hostnamectl --transient set-hostname "ip-''${ip//./-}"
          echo "hostname set to ip-''${ip//./-}"
          exit 0
        fi
        sleep 1
      done

      # Non-zero so failure is visible in `systemctl status`/the journal.
      # `before = nomad.service` above is ordering only — Nomad still starts
      # and registers under the fallback name if this fails.
      echo "no IPv4 source address after 60s — hostname left underived" >&2
      exit 1
    '';
  };
}
