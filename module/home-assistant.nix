# Home Assistant as a Nomad service job (podman driver), for the rpi4b kiosk to
# point at. Three things have to line up:
#
#   1. State — HA's /config (SQLite recorder, .storage registries) is node-local,
#      so the job is pinned to one box via a host_volume + a node constraint.
#      Pinning is deliberate-for-now; EVA-169 researches making it movable.
#   2. Name — the kiosk hardcodes http://homeassistant.local:8123/. The Pi gets no
#      networking.extraHosts (hosts/rpi doesn't import hosts/shared.nix) but does
#      run avahi+nssmdns4, so the name is published over mDNS from the pinned node.
#   3. Auth — hosts/rpi/graphical.nix starts Firefox on a fresh `mktemp -d` profile
#      every boot, so HA's localStorage token is wiped on every reboot and the kiosk
#      would sit on a login screen forever. The trusted_networks auth provider is
#      what makes the kiosk work at all, not a nicety.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.homeAssistantJob;

  yaml = pkgs.formats.yaml { };
  json = pkgs.formats.json { };

  # NOTE: only the `homeassistant` provider can create the owner account during
  # onboarding, so it stays listed even though the kiosk never uses it. Dropping it
  # would lock everyone out of password login.
  configYaml = yaml.generate "configuration.yaml" {
    default_config = { };

    homeassistant.auth_providers = [
      {
        type = "trusted_networks";
        trusted_networks = cfg.trustedNetworks;
        # Skips the login form outright, but only while exactly one HA user exists.
        # Add a second user and this degrades to a user picker unless trusted_users
        # is filled in with that user's UUID (which only exists after onboarding).
        allow_bypass_login = true;
      }
      { type = "homeassistant"; }
    ];

    http.server_port = cfg.port;
  };

  jobJson = json.generate "home-assistant.json" {
    Job = {
      ID = "home-assistant";
      Name = "home-assistant";
      Type = "service";
      Datacenters = [ "home" ];

      TaskGroups = [
        {
          Name = "ha";
          Count = 1;

          # The server boxes have no static hostname (derive-hostname sets a
          # transient ip-a-b-c-d from DHCP), so this target can drift. If the job
          # goes pending, check `nomad node status` names first.
          Constraints = [
            {
              LTarget = "\${attr.unique.hostname}";
              Operand = "=";
              RTarget = cfg.nodeName;
            }
          ];

          Volumes.hass = {
            Name = "hass";
            Type = "host";
            Source = "hass";
            ReadOnly = false;
          };

          Tasks = [
            {
              Name = "home-assistant";
              Driver = "podman";

              Config = {
                image = cfg.image;
                # HA's discovery is SSDP/mDNS — it finds nothing behind a bridge.
                network_mode = "host";
                # configuration.yaml is generated, so mount it read-only over the
                # writable state volume. HA never writes this file itself.
                volumes = [ "${configYaml}:/config/configuration.yaml:ro" ];
              };

              VolumeMounts = [
                {
                  Volume = "hass";
                  Destination = "/config";
                  ReadOnly = false;
                }
              ];

              Env.TZ = config.time.timeZone;

              Resources = {
                CPU = cfg.cpu;
                MemoryMB = cfg.memoryMB;
              };
            }
          ];
        }
      ];
    };
  };

  # Every server box runs this module, but only the pinned one may claim the mDNS
  # name — two publishers of homeassistant.local is a name collision.
  publishAlias = pkgs.writeShellScript "publish-homeassistant-alias" ''
    if [ "$(${pkgs.nettools}/bin/hostname)" != "${cfg.nodeName}" ]; then
      echo "not the HA node (${cfg.nodeName}); nothing to publish"
      exit 0
    fi

    ip=$(${pkgs.iproute2}/bin/ip -4 route get 1.1.1.1 \
      | ${pkgs.gawk}/bin/awk '{ for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit } }')

    if [ -z "$ip" ]; then
      echo "no primary IPv4 to publish" >&2
      exit 1
    fi

    exec ${pkgs.avahi}/bin/avahi-publish -a -R ${cfg.aliasName} "$ip"
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
      description = "Host path backing the `hass` Nomad host volume (HA's /config).";
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
    # Declared on every box so the volume exists wherever the pin is moved to.
    services.nomad.settings.client.host_volume.hass = {
      path = cfg.stateDir;
      read_only = false;
    };

    systemd.tmpfiles.rules = [ "d ${cfg.stateDir} 0750 root root - -" ];

    # Same shape as pi-agent-register (module/pibot.nix): idempotent oneshot that
    # POSTs the jobspec once Nomad's ACL bootstrap has landed. Runs on all three
    # boxes; re-registering an identical spec is a no-op.
    systemd.services.home-assistant-register = {
      description = "Register the home-assistant Nomad job";
      after = [ "nomad-acl-bootstrap.service" ];
      requires = [ "nomad-acl-bootstrap.service" ];
      wantedBy = [ "multi-user.target" ];
      environment.NOMAD_ADDR = "http://127.0.0.1:4646";
      path = with pkgs; [
        curl
        coreutils
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -u
        umask 077
        tmp=$(mktemp)
        trap 'rm -f "$tmp"' EXIT
        tr -d '[:space:]' < ${config.sops.secrets."nomad/bootstrap_token".path} > "$tmp"
        token=$(cat "$tmp")

        for _ in $(seq 1 60); do
          code=$(curl -s -o /dev/null -w '%{http_code}' \
            -H "X-Nomad-Token: $token" \
            -X POST "$NOMAD_ADDR/v1/jobs" \
            --data @${jobJson}) || code=000
          case "$code" in
            200)
              echo "home-assistant job registered"
              exit 0
              ;;
            *)
              sleep 2
              ;;
          esac
        done
        echo "home-assistant registration failed after retries" >&2
        exit 1
      '';
    };

    systemd.services.homeassistant-mdns-alias = {
      description = "Publish ${cfg.aliasName} over mDNS for the kiosk";
      after = [ "avahi-daemon.service" ];
      wants = [ "avahi-daemon.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = publishAlias;
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
