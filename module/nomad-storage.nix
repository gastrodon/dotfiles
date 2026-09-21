# Durable storage for the Nomad cluster nodes (EVA-302).
#
# Nomad must never start with a host volume whose backing store is volatile —
# see wiki: Nomad storage durability design for why and the incidents this
# prevents (EVA-325, EVA-369).
#
# No per-node hostname/IP branching: the disk's own label carries the truth
# (.58/.17 have a `nomad-data`-labelled disk mounted at /data, .5 does not and
# runs stateless). Adding/removing a disk-bearing node is `mkdir
# /data/volumes` on its disk, not an image rebuild.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.nomadStorage;

  # Hardcoded, not options: see wiki: Nomad storage durability design.
  mountPoint = "/data";
  mountUnit = "data.mount";

  volumeRoot = "${mountPoint}/volumes";
  stateSource = "${mountPoint}/nomad";
  containersSource = "${mountPoint}/containers";

  # Rendered Nomad host-volume config fragments, one per volume. On tmpfs
  # (/run) on purpose: see wiki: Nomad storage durability design.
  fragmentDir = "/run/nomad-host-volumes.d";

  volumeOpts = {
    options = {
      uid = lib.mkOption {
        type = lib.types.int;
        description = ''
          Numeric owner of the volume directory on the host (podman is
          rootful, so this passes straight through to the container).
        '';
      };

      gid = lib.mkOption {
        type = lib.types.int;
        description = "Numeric group of the volume directory. See `uid`.";
      };

      mode = lib.mkOption {
        type = lib.types.strMatching "0[0-7][0-7][0-7]";
        default = "0700";
        description = "Octal mode of the volume directory.";
      };

      comment = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Why this uid — kept next to the number so it can be checked.";
      };
    };
  };

  # `enabled = true` is load-bearing, not a restatement of the default — see
  # D1 in wiki: Nomad storage durability design (HCL1's JSON decoder rejects a
  # bare host_volume block).
  renderVolumeFragment =
    name: _:
    pkgs.writeText "nomad-host-volume-${name}.json" (
      builtins.toJSON {
        client = {
          enabled = true;
          host_volume.${name} = {
            path = "${volumeRoot}/${name}";
            read_only = false;
          };
        };
      }
    );

  volumeFragments = lib.mapAttrs renderVolumeFragment cfg.volumes;

  # D2: enumerate, never create — see wiki: Nomad storage durability design.
  # Presence of ${volumeRoot}/<name> is proof the disk-prep runbook put data
  # there; this unit only ever reads it, never creates it.
  installFragments = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: frag: ''
      if [ -d ${lib.escapeShellArg "${volumeRoot}/${name}"} ]; then
        install -m 0444 ${frag} ${fragmentDir}/${name}.json
        declared="$declared ${name}"
      fi
    '') volumeFragments
  );

  volumeNames = lib.attrNames cfg.volumes;

  # What to do once /data has been found to be volatile.
  volatileAction =
    if cfg.requireDurableData then
      ''
        echo "REFUSING to start Nomad. A host volume on volatile storage loses its" >&2
        echo "data at the next reboot with no error anywhere -- see EVA-325." >&2
        echo "Attach or repair the disk, or set" >&2
        echo "services.nomadStorage.requireDurableData = false to run this node" >&2
        echo "as a stateless worker on purpose." >&2
        exit 1
      ''
    else
      ''
        echo "requireDurableData = false: starting Nomad with NO host volumes." >&2
        echo "Stateful jobs will stay pending on this node, which is correct." >&2
        install -d -m 0755 ${fragmentDir}
        exit 0
      '';

  # Bind a directory onto durable storage, but ONLY if it would otherwise be
  # volatile — see wiki: Nomad storage durability design.
  mkDurableBind =
    {
      target,
      source,
      mode,
      what,
    }:
    ''
      backing=$(findmnt --noheadings --output FSTYPE --target ${target} 2>/dev/null || true)
      case "$backing" in
        tmpfs | ramfs | overlay | "")
          install -d -m ${mode} -o 0 -g 0 ${source}
          install -d -m ${mode} -o 0 -g 0 ${target}
          if ! mountpoint -q ${target}; then
            mount --bind ${source} ${target}
            echo "bound ${source} -> ${target} (${what})"
          fi
          ;;
        *)
          echo "${target} already durable on $backing -- left alone."
          ;;
      esac
    '';

  # Nomad's own state; cannot be a host volume (must exist before Nomad
  # starts). See wiki: Nomad storage durability design (EVA-337).
  bindState = lib.optionalString cfg.bindStateDir (mkDurableBind {
    target = "/var/lib/nomad";
    source = stateSource;
    mode = "0700";
    what = "node id, raft, variables keyring";
  });

  # Podman's image/container store. Durable Nomad state without this is worse
  # than neither (2026-09-10 incident) — see wiki: Nomad storage durability
  # design. 0755 matches what podman already uses.
  bindContainers = lib.optionalString cfg.bindContainersDir (mkDurableBind {
    target = "/var/lib/containers";
    source = containersSource;
    mode = "0755";
    what = "podman image + container store";
  });

in
{
  options.services.nomadStorage = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Mount the data disk at /data and publish the directories under
        /data/volumes to Nomad as static host volumes.

        Safe to enable on a node that has no data disk: such a node declares no
        volumes and simply never has a stateful job placed on it.
      '';
    };

    device = lib.mkOption {
      type = lib.types.str;
      default = "/dev/disk/by-label/nomad-data";
      description = ''
        The data disk, addressed by label (not /dev/sdX or by-id — disks get
        physically swapped between boxes; see wiki: Nomad storage durability
        design).
      '';
    };

    fsType = lib.mkOption {
      type = lib.types.str;
      default = "ext4";
      description = ''
        Plain ext4, one GPT partition, whole disk, subdivided by directory.
        Not btrfs/LVM/XFS — see wiki: Nomad storage durability design.
      '';
    };

    requireDurableData = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        When /data turns out to be backed by volatile storage, refuse to let
        Nomad start at all instead of starting it with no volumes. See wiki:
        Nomad storage durability design.
      '';
    };

    bindContainersDir = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Bind /data/containers onto /var/lib/containers when, and only when,
        /var/lib/containers would otherwise land on volatile storage.
      '';
    };

    bindStateDir = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Bind-mount /data/nomad onto /var/lib/nomad when, and only when,
        /var/lib/nomad would otherwise land on volatile storage (EVA-337). See
        wiki: Nomad storage durability design.
      '';
    };

    volumes = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule volumeOpts);
      description = ''
        Host volumes to create under /data/volumes and advertise to Nomad, by
        name. The attribute name is the Nomad volume name a jobspec's
        `volume` stanza refers to.

        This is the universe of volumes, not a per-node list — which node
        actually declares them is decided at boot by whether that node's disk
        carries a /data/volumes directory at all.
      '';

      # uid/gid table and per-service rationale: wiki: Nomad storage
      # durability design.
      default = {
        mysql = {
          uid = 999;
          gid = 999;
          mode = "0700";
          comment = "mysqld's image-default uid; rootful podman passes it straight through";
        };

        rabbitmq = {
          uid = 999;
          gid = 999;
          mode = "0700";
          comment = "beam.smp re-execs as uid 999; confirmed with podman top";
        };

        home-assistant = {
          uid = 0;
          gid = 0;
          mode = "0750";
          comment = "HA image runs as root; matches today's /var/lib/hass";
        };

        ollama = {
          uid = 0;
          gid = 0;
          mode = "0750";
          comment = "ollama image runs as root; matches today's /var/lib/ollama";
        };

        traefik = {
          uid = 0;
          gid = 0;
          mode = "0700";
          comment = "acme.json private keys; traefik image runs as root";
        };

        # Generated site content; nothing else on this node makes it durable
        # across a netboot reboot. See wiki: Nomad storage durability design.
        testbench = {
          uid = 0;
          gid = 0;
          mode = "0755";
          comment = "generated site; served read-only, published by the testbench repo's deploy";
        };

        # Multi-job scratch space; declare on exactly ONE node. See wiki:
        # Nomad storage durability design (EVA-369).
        shared = {
          uid = 0;
          gid = 0;
          mode = "1777";
          comment = "multi-job scratch (EVA-369); sticky like /tmp — declare on ONE node only";
        };

        # Pinned to .17, not .58 — disk load-balancing against `shared`'s IO.
        gitea = {
          uid = 1000;
          gid = 1000;
          mode = "0750";
          comment = "gitea/gitea image-default uid; confirmed live via podman top + id git";
        };

        # Pinned to .58 — single-node Raft constraint (EVA-303).
        vault = {
          uid = 100;
          gid = 1000;
          mode = "0700";
          comment = "vault image-default uid/gid; confirmed via `podman run ... id`";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.all (n: builtins.match "[a-zA-Z0-9_-]+" n != null) volumeNames;
        message =
          "services.nomadStorage.volumes: Nomad host volume names may only contain "
          + "[a-zA-Z0-9_-]; rejected: "
          + lib.concatStringsSep ", " (
            lib.filter (n: builtins.match "[a-zA-Z0-9_-]+" n == null) volumeNames
          );
      }
    ];

    # `nofail`, not `x-systemd.required-by=nomad.service` — see wiki: Nomad
    # storage durability design.
    fileSystems.${mountPoint} = {
      device = cfg.device;
      fsType = cfg.fsType;
      options = [
        "nofail"
        # Bounded, because with nofail the default 90s device wait is 90s of a
        # box that is already known to be in trouble sitting there not booting.
        "x-systemd.device-timeout=10s"
        # Ordering only — see above for why this is not a requirement. It makes
        # the mount attempt complete before Nomad regardless of the gate unit.
        "x-systemd.before=nomad.service"
        # Nothing under here reads atime, and MySQL and ollama generate enough
        # write traffic already.
        "noatime"
      ];
    };

    systemd.services.nomad-host-volumes = {
      description = "Prove /data is durable, then publish Nomad host volumes";

      # `wants` + `after` (not `requires`) on data.mount, since it's `nofail`
      # and needs to be waited on rather than hard-required. See wiki: Nomad
      # storage durability design.
      wants = [ mountUnit ];
      after = [
        mountUnit
        "local-fs.target"
      ];

      # requiredBy nomad.service: a failure here must stop Nomad from
      # starting with silently-dropped volumes.
      #
      # Ordered before podman.service but deliberately NOT before
      # podman.socket — doing so creates a systemd ordering cycle that
      # silently drops a unit (real incident 2026-09-10, see wiki: Nomad
      # storage durability design).
      before = [
        "nomad.service"
        "podman.service"
      ];
      requiredBy = [ "nomad.service" ];

      # wantedBy multi-user.target so a node that fails this check still
      # finishes booting and is reachable over SSH to be fixed.
      wantedBy = [ "multi-user.target" ];

      path = with pkgs; [
        util-linux
        coreutils
        nomad
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        set -euo pipefail

        # Is this machine supposed to have a data disk at all? Checked before
        # the durability gate below (added 2026-09-11, EVA-369) — see wiki:
        # Nomad storage durability design for why this distinction exists.
        if [ ! -e ${cfg.device} ]; then
          echo "${cfg.device} is not present on this machine."
          echo "No data disk was ever attached here -- starting Nomad as a"
          echo "stateless worker and declaring no host volumes."
          rm -rf ${fragmentDir}
          install -d -m 0755 ${fragmentDir}
          exit 0
        fi

        # THE GATE. `|| true`: an unreadable answer must refuse, never
        # silently pass. See wiki: Nomad storage durability design.
        backing=$(findmnt --noheadings --output FSTYPE --target ${mountPoint} 2>/dev/null || true)

        case "$backing" in
          tmpfs | ramfs | overlay | "")
            echo "${mountPoint} is backed by ''${backing:-nothing} -- volatile." >&2
            echo "The data disk (${cfg.device}) did not mount, or was never attached." >&2
            ${volatileAction}
            ;;
        esac

        echo "${mountPoint} is backed by $backing -- durable."

        ${bindState}
        ${bindContainers}

        # Start from an empty fragment directory every boot; nothing carries
        # over from a previous boot's judgement.
        rm -rf ${fragmentDir}
        install -d -m 0755 ${fragmentDir}

        # ${volumeRoot} is the marker that this disk carries the cluster's
        # stateful services, created once by the disk-prep runbook.
        if [ ! -d ${volumeRoot} ]; then
          echo "no ${volumeRoot} on this disk — declaring no host volumes."
          echo "(mkdir ${volumeRoot}/<name> on the box that holds the data.)"
          exit 0
        fi

        declared=""
        ${installFragments}

        # An undeclared subdirectory is almost certainly a runbook typo, not
        # something to ignore silently.
        for d in ${volumeRoot}/*/; do
          [ -e "$d" ] || continue
          n=$(basename "$d")
          case " ${lib.concatStringsSep " " (lib.attrNames cfg.volumes)} " in
            *" $n "*) ;;
            *) echo "WARNING: ${volumeRoot}/$n exists but is not declared in services.nomadStorage.volumes — ignoring." >&2 ;;
          esac
        done

        # Validate before Nomad starts — catches D1-class errors here, loudly,
        # instead of a nomad.service restart loop.
        if ! nomad config validate /etc/nomad.json ${fragmentDir} >/dev/null 2>&1; then
          echo "REFUSING to start Nomad: generated host-volume config does not validate." >&2
          nomad config validate /etc/nomad.json ${fragmentDir} >&2 || true
          rm -rf ${fragmentDir}
          exit 1
        fi

        echo "declared host volumes:''${declared:- (none)}"
      '';
    };

    # Second, independent fail-closed layer: `nomad agent -config=<missing
    # file>` exits rather than warning, so a skipped unit still can't start
    # Nomad with silently-forgotten volumes.
    services.nomad.extraSettingsPaths = [ fragmentDir ];

    # Otherwise systemd's StateDirectory= reopens the bind-mounted state dir
    # to 0755 on every start, exposing the secret id and Variables keyring.
    systemd.services.nomad.serviceConfig.StateDirectoryMode = "0700";
  };
}
