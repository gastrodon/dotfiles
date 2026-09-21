# This module no longer defines the Nomad job (spec moved to
# ~/code/home-infra/infra/home-assistant.nomad.hcl) — only the firewall port
# and state directory with correct ownership remain here. `enable = false`
# also drops those, not just an already-nonexistent job. See wiki:
# Job-registration split
# (https://linear.app/gastrodon/document/job-registration-split-firewallstate-dir-only-modules-91e3fa6c89ae).
#
# Home Assistant as a Nomad service job (podman driver), for the rpi4b kiosk
# to point at. The kiosk's Firefox profile is wiped every boot (`mktemp -d`),
# so `trusted_networks` auth below is load-bearing — remove it and the kiosk
# sits on a login screen forever. See the wiki doc above for the rest of what
# has to line up (mDNS naming, node pinning, onboarding auth provider).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.homeAssistantJob;

  yaml = pkgs.formats.yaml { };

  configYaml = yaml.generate "configuration.yaml" {
    default_config = { };

    homeassistant.auth_providers = [
      {
        type = "trusted_networks";
        trusted_networks = cfg.trustedNetworks;
        allow_bypass_login = true;
      }
      { type = "homeassistant"; }
    ];

    http.server_port = cfg.port;
  };

  publishAlias = pkgs.writeShellScript "publish-homeassistant-alias" ''
    while :; do
      if (echo > /dev/tcp/127.0.0.1/${toString cfg.port}) 2>/dev/null; then
        ip=$(${pkgs.iproute2}/bin/ip -4 route get 1.1.1.1 \
          | ${pkgs.gawk}/bin/awk '{ for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit } }')

        if [ -n "$ip" ]; then
          echo "HA is serving locally; publishing ${cfg.aliasName} -> $ip"
          exec ${pkgs.avahi}/bin/avahi-publish -a -R ${cfg.aliasName} "$ip"
        fi
      fi
      sleep 15
    done
  '';
in
{
  options.services.homeAssistantJob = {
    enable = lib.mkEnableOption "Home Assistant as a Nomad job";

    nodeName = lib.mkOption {
      type = lib.types.str;
      default = "server2";
      description = "Nomad node name to pin HA to (must match `nomad node status`).";
    };

    trustedNetworks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "192.168.0.0/24" ];
      description = ''
        CIDRs auto-authenticated without a password. HA matches IP ranges only —
        hostnames and .local names cannot be expressed here. The LAN-wide default
        means any device on the LAN is the HA owner; narrow to the kiosk with
        [ "192.168.0.242/32" ] if that is too broad.
      '';
    };

    aliasName = lib.mkOption {
      type = lib.types.str;
      default = "homeassistant.local";
      description = "mDNS name published for the kiosk URL in hosts/rpi/graphical.nix.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/hass";
      description = "Host path bind-mounted as HA's /config by infra/home-assistant.nomad.hcl.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8123;
      description = "HA HTTP port (host networking, so this is the host port).";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "docker://ghcr.io/home-assistant/home-assistant:stable";
      description = "Container image reference for the podman driver.";
    };

    cpu = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = "Nomad CPU reservation (MHz).";
    };

    memoryMB = lib.mkOption {
      type = lib.types.int;
      default = 2048;
      description = "Nomad memory reservation (MB).";
    };
  };

  config = lib.mkIf cfg.enable {
    # host_volume.hass removed (EVA-302) — nomad-storage.nix owns it now.
    systemd.tmpfiles.rules = [ "d ${cfg.stateDir} 0750 root root - -" ];

    services.avahi.publish.userServices = true;

    systemd.services.homeassistant-mdns-alias = {
      description = "Publish ${cfg.aliasName} over mDNS for the kiosk";
      after = [
        "network-online.target"
        "avahi-daemon.service"
      ];
      wants = [
        "network-online.target"
        "avahi-daemon.service"
      ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = publishAlias;
        # always, not on-failure: avahi-publish exiting cleanly (daemon restart)
        # must send us back to probing, or the name silently disappears.
        Restart = "always";
        RestartSec = 10;
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
