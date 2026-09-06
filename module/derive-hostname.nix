# EC2-style hostname derived from the node's own LAN address (EVA-301, EVA-192).
#
# Sets `ip-a-b-c-d` from the primary IPv4 before anything that captures the
# hostname reads it. This is what lets ONE image serve every box: identity comes
# from the DHCP reservation rather than from anything baked per machine, so the
# same bytes booted anywhere produce a correctly-named node, and a node that
# reboots re-registers as the same node instead of accumulating a new entry in
# Nomad's peer set.
#
# THE UNIT WAS NEVER THE PROBLEM — THIS ALSO FIXES THE THING THAT DEFEATED IT.
#
# The unit below already existed in hosts/server/configuration.nix and already
# worked: the journal shows the log prefix changing mid-boot from `server1` to
# `ip-192-168-0-58` as it ran. And yet the boxes answered to `server1` and
# `server2` anyway, which is EVA-192.
#
# The reason is NetworkManager. hosts/shared.nix enables it, its default
# `hostname-mode` resolves the primary address back to a name, and
# networking.extraHosts — generated from module/hosts.nix — puts
# `192.168.0.58 server1` in /etc/hosts. So NetworkManager looked the address up,
# found the old name, and set it back, seconds after this unit had done its job.
#
# The confirming experiment was already sitting in the fleet: module/hosts.nix
# has no entry for 192.168.0.5, and 192.168.0.5 was the one box out of three
# that kept its derived name. Same config, same unit, different outcome, and the
# only difference was a line in /etc/hosts.
#
# `hostname-mode = "none"` tells NetworkManager not to manage the hostname at
# all, which is correct here because something else already owns it.
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

    # DELIBERATELY NOT `network-online.target`, WHICH IS THE OBVIOUS CHOICE AND
    # IS WRONG HERE.
    #
    # Nothing in NixOS provides network-online.target on its own — it is
    # satisfied by whichever *-wait-online service the active networking backend
    # ships. hosts/shared.nix enables NetworkManager, so the disk-booted boxes
    # get NetworkManager-wait-online and the unit fires. The netboot node
    # deliberately has no NetworkManager and no networkd (useNetworkd = false,
    # plain dhcpcd), so nothing satisfies the target, the job stays queued
    # forever, and this unit — along with everything ordered after it — never
    # runs at all.
    #
    # Caught by booting the netboot image under QEMU before it ever reached a
    # real box: four minutes in, zero failed units, and the hostname still
    # `nixos`. It fails silently and looks healthy, which is the worst shape for
    # something that decides a node's cluster identity.
    #
    # So order on network.target, which is always reached, and do the waiting in
    # the script where it can be bounded and logged. That also makes this work
    # unchanged under NetworkManager, networkd or bare dhcpcd rather than
    # depending on which one a host happens to use.
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

    # `ip route get` rather than picking the first global-scope address: this
    # asks which source address the kernel would actually use to reach the
    # outside world, so a box with several interfaces names itself after the one
    # carrying its traffic rather than after whichever `ip addr` happens to list
    # first.
    # Poll rather than assume the address is already there. DHCP has not
    # necessarily completed when network.target is reached, and the previous
    # version simply did nothing if it found no address — leaving the node
    # named `nixos` with no error anywhere. Waiting here, with a bound and a
    # loud failure at the end, turns a silent misidentification into something
    # `systemctl status derive-hostname` explains.
    script = ''
      # 180s, not 60. Under QEMU the first netboot test leased an address at
      # t+58s — dhcpcd solicits IPv6 router advertisements before settling IPv4
      # — which would have been inside a 60s bound by a second and a half. A
      # real LAN is far quicker, but the cost of a generous bound is a slower
      # boot in a case that is already broken, and the cost of a tight one is a
      # node silently joining the cluster under the wrong identity.
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

      # Non-zero so the failure is visible in `systemctl status` and in the
      # journal, rather than this exiting 0 having done nothing.
      #
      # Note what this does NOT do: `before = nomad.service` is ordering only,
      # not a requirement, so Nomad still starts and will register the node
      # under the fallback name. Making that a hard dependency would mean a
      # node with no DHCP lease runs no workloads at all — defensible, since
      # such a node is useless anyway, but a bigger behavioural change than
      # belongs in a hostname unit. Left as ordering plus a loud failure.
      echo "no IPv4 source address after 60s — hostname left underived" >&2
      exit 1
    '';
  };
}
