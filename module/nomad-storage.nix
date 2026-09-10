# Durable storage for the Nomad cluster nodes (EVA-302).
#
# THE FAILURE THIS EXISTS TO PREVENT, STATED FIRST, BECAUSE EVERY DESIGN CHOICE
# BELOW IS DOWNSTREAM OF IT: a netbooted node's root filesystem is tmpfs. If a
# Nomad host volume is declared with a path that lives on that tmpfs, Nomad
# advertises the volume, the scheduler places a stateful job onto it, podman
# happily creates the directory, mysqld initialises a fresh empty database into
# RAM, and the whole thing evaporates on the next reboot — with no error
# anywhere. That is EVA-325 (`--datadir=/dev/shm/mysql-data`, twice) with extra
# steps, and it is strictly worse than the node refusing to start.
#
# So the invariant this module enforces is narrow and testable:
#
#   NOMAD NEVER STARTS WITH A HOST VOLUME WHOSE BACKING STORE IS VOLATILE.
#
# Not "the disk mounted". Not "this IP is supposed to have a disk". The actual
# property, checked directly, at the moment it matters.
#
# HOW THE PER-NODE DIFFERENCE FALLS OUT OF THAT, WITH NO PER-NODE CONFIG.
#
# One image serves every box (hosts/cluster-node/configuration.nix), so this
# module cannot branch on which machine it is running on — and an earlier draft
# that tried to, by matching the DHCP address against a baked list of "disk
# nodes", had a fail-open bug: the address lookup raced DHCP, came back empty,
# matched nothing in the list, and fell through to declaring no volumes at all.
# A node whose disk had genuinely failed looked exactly like a node built
# without one. The list is gone. Nothing here reads an IP.
#
# What replaces it is that the disk carries the truth:
#
#   .58 / .17  6 TB ext4 labelled `nomad-data`, prepped with a /data/volumes
#              directory. /data is that disk. Volumes are declared.
#   .5         no such label; /data is an ordinary directory on the 120 GB
#              root SSD (durable, so the gate passes) and has no
#              /data/volumes (so zero volumes are declared). It keeps running
#              exactly as it does today, hosts no stateful jobs, and needed no
#              repartitioning and no entry in any list to arrive there.
#
# Adding or removing a disk-bearing node is `mkdir /data/volumes` on its disk.
# It is not a rebuild of the image that three machines boot from.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.nomadStorage;

  # Hardcoded, not options, and for a sharper reason than "one less knob":
  # `mountUnit` is the name systemd derives from `mountPoint` by its own path
  # escaping. Making the path configurable without also computing the unit name
  # is how the ordering below silently stops applying, and computing it means
  # dragging `utils.escapeSystemdPath` in for a path that has exactly one
  # correct value. /data is where the live data already sits (/data/mysql, the
  # EVA-325 fix), and it deliberately is not /var/lib/nomad-volumes, which sits
  # one typo away from /var/lib/nomad — a different directory with a different
  # job, bind-mounted below.
  mountPoint = "/data";
  mountUnit = "data.mount";

  volumeRoot = "${mountPoint}/volumes";
  stateSource = "${mountPoint}/nomad";
  containersSource = "${mountPoint}/containers";

  # /run, not /etc or /var: tmpfs, so it cannot survive a reboot. A stale
  # fragment describing volumes that this boot has not proven durable is
  # precisely the thing that must not exist, and putting it in /run makes that
  # structural instead of something the unit has to remember to clean up.
  #
  # A DIRECTORY, not a single file, and that is D2's fix. One fragment per
  # volume, rendered at eval time; the unit installs only those whose data
  # directory actually exists. Verified with `nomad config validate`: a
  # directory of fragments validates, an existing-but-empty one validates, and
  # a MISSING one errors — so fail-closed survives the change.
  fragmentDir = "/run/nomad-host-volumes.d";

  volumeOpts = {
    options = {
      uid = lib.mkOption {
        type = lib.types.int;
        description = ''
          Numeric owner of the volume directory on the host.

          Numeric on purpose. Podman here is ROOTFUL, so a container's uid is
          the host's uid with no mapping in between, and the number that
          matters is the one baked into the image — not whatever the host's
          /etc/passwd happens to call it. On these boxes uid 999 is displayed
          as `avahi`, which is a coincidence of allocation order and would be
          an actively misleading thing to write down.
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

  # Rendered here, in Nix, rather than assembled by a shell loop at boot: jq is
  # closure weight on a node with 7.7 GiB of RAM, and a volume name that needs
  # shell escaping is one that should have failed the build (see assertions).
  #
  # `enabled = true` IS LOAD-BEARING AND IS NOT A RESTATEMENT OF THE DEFAULT.
  # This is D1, found by review and confirmed against nomad 1.11.3 on .5:
  #
  #   {"client":{"host_volume":{...}}}                 -> Nomad REFUSES TO START
  #     "Error loading configuration: unexpected keys host_volume"
  #   {"client":{"host_volume":{}}}                    -> same error
  #   {"client":{"enabled":true,"host_volume":{...}}}  -> "Configuration is valid!"
  #
  # HCL1's JSON decoder flattens an object whose every member is itself an
  # object into a labelled block, and Nomad then rejects the label. A scalar
  # sibling stops the flattening. The empty case fails too, so the earlier
  # single-fragment design broke Nomad on EVERY node including .5 — which
  # declares nothing and would have been the safest canary.
  #
  # Note what this means about validation: `builtins.toJSON` cannot emit
  # malformed JSON, and that was never the risk. The JSON was well-formed and
  # still wrong. Only `nomad config validate` catches this, which is why the
  # unit runs it before letting Nomad start.
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

  # D2's fix: ENUMERATE, NEVER CREATE.
  #
  # The previous version created every volume directory it knew about, which
  # made a node with no data indistinguishable from a node holding 11 GB of it.
  # Both 6 TB boxes then advertised all five volumes and the scheduler was free
  # to place Home Assistant onto the empty one — blank onboarding, real state
  # stranded on the other node, no error anywhere. For mysql it is worse: the
  # jobspec's provision task recreates the schema and exits 0, so you get a
  # schema-correct, data-EMPTY database. That is EVA-325's exact silent shape.
  #
  # So the presence of ${volumeRoot}/<name> is now PROOF that the disk-prep
  # runbook put data there, and this unit only ever reads it. Creating a volume
  # is a deliberate act performed once, by a human, on the box that holds the
  # data — not something a config that three boxes share does implicitly.
  installFragments = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: frag: ''
      if [ -d ${lib.escapeShellArg "${volumeRoot}/${name}"} ]; then
        install -m 0444 ${frag} ${fragmentDir}/${name}.json
        declared="$declared ${name}"
      fi
    '') volumeFragments
  );

  volumeNames = lib.attrNames cfg.volumes;

  # What to do once /data has been found to be volatile. Both branches are
  # spelled out here rather than inline in the case statement so that the two
  # possible endings of that branch can be read side by side — the whole
  # argument for keeping `requireDurableData` at all is that neither of them
  # can declare a volume, and that is easier to check when they are adjacent.
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
  # volatile. The condition is as important as the action: on a disk-booted node
  # these paths are already on the root SSD, and relocating .5's live Nomad node
  # identity and Raft log onto an empty directory is a way to lose a cluster
  # rather than save one.
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

  # Nomad's OWN state, which is not a host volume and cannot be one: it has to
  # exist before the agent starts, and a host volume is mounted by Nomad, for a
  # task, after it has started. Since 1.9 this also holds the wrapped root key
  # that every Nomad Variable is encrypted under, so on an all-netboot cluster
  # losing it means losing every stored credential.
  bindState = lib.optionalString cfg.bindStateDir (mkDurableBind {
    target = "/var/lib/nomad";
    source = stateSource;
    mode = "0700";
    what = "node id, raft, variables keyring";
  });

  # Podman's image and container store. Making Nomad's state durable WITHOUT
  # this is actively worse than making neither durable, which is how it was
  # found on 2026-09-10: the client came back remembering allocations that
  # podman had forgotten, logged
  #
  #   Failed Restoring Task: failed to restore task; will not run until server
  #   is contacted
  #
  # and re-pulled every image. Two costs, neither obvious:
  #
  #   1. Every boot depends on the registry being reachable. A node rebooting
  #      during a Docker Hub outage does not come back.
  #   2. The images live in RAM. Measured 4.8 GB of tmpfs on .17 -- on a box
  #      that netboots, image storage is a straight subtraction from usable
  #      memory, and it grows with every image ever pulled.
  #
  # Cost of the fix, stated plainly: image storage moves onto a spinning SMR
  # disk, so the first pull of a NEW image gets slower. Reboots get much
  # faster, and reboot is the deploy mechanism here, so that is the right way
  # round. 0755 matches what podman already uses.
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
        The data disk, addressed by label.

        Label and not /dev/sdX, and not by-id either. These boxes have had
        their disks physically swapped — the 6 TB replaces the SSD rather than
        joining it, because there is one 3.5" bay and one usable SATA power
        lead per chassis — so /dev/sda names a different disk before and after,
        and a by-id path names one specific serial number and would have to be
        edited per box in an image that three boxes share. The label is the
        only name that means "the disk I formatted for this", on every box,
        before and after the swap.
      '';
    };

    fsType = lib.mkOption {
      type = lib.types.str;
      default = "ext4";
      description = ''
        Plain ext4, one GPT partition, whole disk, subdivided by directory.

        Not btrfs: MySQL on CoW needs `chattr +C`, which switches off the
        checksums and snapshots that were the reason to pick btrfs, on exactly
        the dataset that most wants them. Not LVM: it buys hard isolation
        between services that a home cluster does not need, and gives up the
        elastic sharing that plain directories provide for free. Not XFS:
        nothing here stresses parallel-write or huge-directory metadata.
      '';
    };

    requireDurableData = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        When /data turns out to be backed by volatile storage (tmpfs on a
        netbooted node whose disk did not mount), refuse to let Nomad start at
        all instead of starting it with no volumes.

        Default true, and the default is the whole point: a node that was
        supposed to have a disk and does not is a node that must be looked at,
        not one that quietly rejoins the cluster as a stateless worker while
        somebody wonders where Home Assistant went.

        Setting this false does NOT make volatile volumes possible. It cannot:
        the only other branch declares an empty volume set. The choice is
        between "Nomad refuses to start" and "Nomad starts with no volumes",
        never "Nomad starts with a volume backed by RAM". It exists so the
        netboot image can be booted under QEMU with no disk attached without
        the agent being dead on arrival.
      '';
    };

    bindContainersDir = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Bind /data/containers onto /var/lib/containers when, and only when,
        /var/lib/containers would otherwise land on volatile storage.

        Podman's image and container store. On a netbooted node this is tmpfs,
        which has two consequences that only became visible once Nomad's own
        state was made durable: the client remembers allocations podman has
        forgotten and re-pulls every image on every boot, and the images
        themselves occupy RAM (4.8 GB measured on .17).

        Ordered before podman as well as before Nomad. Binding over a directory
        podman already has open would leave it writing to a hidden inode.
      '';
    };

    bindStateDir = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Bind-mount /data/nomad onto /var/lib/nomad when, and only when,
        /var/lib/nomad would otherwise land on volatile storage (EVA-337).

        This is a different problem from host volumes and it is worth being
        clear about why it lives in the same unit. A host volume is mounted by
        Nomad, for a task, after Nomad has started. Nomad's own state — client
        id, secret id, node id, the Raft log, and since 1.9 the wrapped root
        key that every Nomad Variable is encrypted under — has to exist before
        Nomad starts. Same disk, same durability question, opposite side of
        `nomad.service`. Only this unit runs early enough to do both.

        The condition matters as much as the action: on a disk-booted node
        /var/lib/nomad is already on the root SSD and already durable, so
        nothing is bind-mounted and nothing moves. Doing it unconditionally
        would relocate 192.168.0.5's live node identity and Raft log to an
        empty directory, which is a way to lose a cluster rather than save one.
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

      default = {
        # `docker.io/library/mysql`'s server drops to its image-default uid 999
        # itself; the jobspec sets no `user`. Verified on the live box: /data/mysql
        # on .58 is 999:999, mode 700, 201 MB, and it is the only live copy —
        # .17's is a 189 MB drift-era leftover that must never be restored over it.
        mysql = {
          uid = 999;
          gid = 999;
          mode = "0700";
          comment = "mysqld's image-default uid; rootful podman passes it straight through";
        };

        # rabbitmq:3-management starts as root and re-execs the broker as uid 999.
        # Verified live on .17: `podman top` reports host user 999 for beam.smp,
        # and the container's /var/lib/rabbitmq is 999:999.
        #
        # This volume is new. The job has no durable storage at all today — its
        # queue state sits in a podman-managed anonymous volume that no jobspec
        # references — so declaring the volume here is the half of that fix a
        # NixOS module is allowed to make.
        rabbitmq = {
          uid = 999;
          gid = 999;
          mode = "0700";
          comment = "beam.smp re-execs as uid 999; confirmed with podman top";
        };

        # ghcr.io/home-assistant/home-assistant runs as root and the jobspec sets
        # no `user`. /var/lib/hass on .17 is root:root 0750 and its contents
        # (home-assistant_v2.db, .storage/) are root-owned throughout.
        home-assistant = {
          uid = 0;
          gid = 0;
          mode = "0750";
          comment = "HA image runs as root; matches today's /var/lib/hass";
        };

        # Same: ollama runs as root, /var/lib/ollama on .58 is root:root 0750.
        # 11 GB of models, which is what makes this one worth moving off the
        # 120 GB root SSD rather than merely worth keeping.
        ollama = {
          uid = 0;
          gid = 0;
          mode = "0750";
          comment = "ollama image runs as root; matches today's /var/lib/ollama";
        };

        # traefik:v3.3 runs as root. acme.json is the only durable thing it has,
        # and Let's Encrypt certificates are rate-limited, so re-issuing them on
        # every reschedule is a way to get locked out rather than a minor cost
        # (EVA-274). 0700 because acme.json holds private keys.
        traefik = {
          uid = 0;
          gid = 0;
          mode = "0700";
          comment = "acme.json private keys; traefik image runs as root";
        };

        # testbench-web's 12 MB of generated site. This was originally left out
        # on the grounds that the content lives in /home/eva/testbench-web and
        # is pushed there by `nix run .#deploy` from the testbench repo, making
        # it a deploy target rather than durable state.
        #
        # That reasoning does not survive netboot, and .17 proved it on
        # 2026-09-10: the node's root is tmpfs, so /home/eva does not persist
        # and there is nothing for a deploy to push *into* that outlives a
        # reboot. Re-creatable-from-source is not the same as
        # re-created-automatically — nothing re-runs that deploy on boot, so
        # without a volume the site is simply gone until a human notices.
        #
        # read_only is NOT set here: the volume declaration stays writable so a
        # deploy can update it in place, and the jobspec marks its own
        # volume_mount read-only instead. That keeps the container unable to
        # scribble on the site while leaving the publish path open.
        # A shared scratch volume for jobs that cooperate on one dataset —
        # the distributed reverse-engineering workflow (EVA-369) is the case
        # that prompted it: several workers fanning out over one corpus of
        # extracted assets and compiler artifacts.
        #
        # Nomad host volumes are NOT exclusive. Several allocations on the same
        # node can each declare `volume { source = "shared" }` and every one of
        # them gets the same directory bind-mounted. That is the whole feature,
        # and it needs no NFS, no CSI plugin and no new daemon.
        #
        # DECLARE THIS ON EXACTLY ONE NODE. That is not a limitation to work
        # around, it is the correctness property. If two nodes both carried a
        # `shared` directory, two jobs claiming the same volume could be placed
        # on different boxes and quietly operate on different data — the same
        # class of failure as the empty-volume trap, wearing a different hat.
        # One directory on one box means "sharing" is enforced by construction:
        # Nomad can only place the claimants where the volume exists, so they
        # co-locate whether or not anyone remembered to constrain them.
        #
        # 1777, i.e. /tmp's mode, and for /tmp's reason. Jobs sharing this will
        # not agree on a uid — podman here is rootful so a container's uid is
        # the host's, and EVA-369's workers run under the `exec` driver as root
        # while other jobs do not. World-writable with the sticky bit lets any
        # of them write while stopping one from deleting another's output. On a
        # single-tenant home cluster of first-party jobs that is the honest
        # trade; if it ever hosts something less trusted, this is the line to
        # revisit first.
        shared = {
          uid = 0;
          gid = 0;
          mode = "1777";
          comment = "multi-job scratch (EVA-369); sticky like /tmp — declare on ONE node only";
        };

        testbench = {
          uid = 0;
          gid = 0;
          mode = "0755";
          comment = "generated site; served read-only, published by the testbench repo's deploy";
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

    # `nofail`, and that is not laziness about a disk that should be there.
    #
    # Without it the mount is required by local-fs.target, and a box with a
    # dead or absent data disk hangs in early boot instead of coming up. The
    # box that is usually the Raft leader sitting at a mount prompt, unreachable
    # over SSH, is a worse outcome than the same box booting, refusing to start
    # Nomad, and saying why in the journal — which is exactly what the unit
    # below arranges. The safety property is enforced by that unit, not by
    # making the mount mandatory.
    #
    # Note what is NOT here: `x-systemd.required-by=nomad.service`. That is the
    # obvious way to read "Nomad cannot start before the mount" and it is wrong,
    # because 192.168.0.5 has no disk with this label and never will — making
    # nomad.service require data.mount would stop Nomad from ever starting
    # there. The requirement is that Nomad not start on *volatile* storage, and
    # only something that looks at the result can tell the difference.
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

      # ORDERING IS THE ENTIRE POINT OF THIS UNIT.
      #
      # `wants` + `after` on data.mount rather than `requires`: nofail means
      # systemd does not order the mount before local-fs.target at all, so
      # ordering on local-fs.target alone would let this run before the mount
      # had even been attempted and misjudge a perfectly good disk. Wants pulls
      # the mount job in; After waits for it to finish activating *or failing*,
      # which is what lets the volatile-storage branch below be reached at all
      # rather than deadlocking behind a mount that is never going to succeed.
      wants = [ mountUnit ];
      after = [
        mountUnit
        "local-fs.target"
      ];

      # requiredBy, not wantedBy, and this is the load-bearing line: a failure
      # here must stop nomad.service, because a Nomad that starts without this
      # fragment is a Nomad that has silently dropped every host volume.
      # Ordered before podman.service so the bind lands before the daemon opens
      # /var/lib/containers — binding over a directory podman already has open
      # would leave it writing to a hidden inode.
      #
      # DELIBERATELY *NOT* before podman.socket. That creates an ordering cycle
      # and systemd resolves it by deleting a unit, nondeterministically:
      #
      #   Found ordering cycle: podman.socket/start after
      #   nomad-host-volumes.service/start after basic.target/start after
      #   sockets.target/start - after podman.socket
      #   Job podman.socket/start deleted to break ordering cycle
      #
      # sockets.target wants podman.socket, and this unit is a normal service so
      # it implicitly orders after basic.target, which is after sockets.target.
      # Naming podman.socket in `before` closes the loop. Observed 2026-09-10:
      # .17 booted with podman.socket dropped and every containerised job died
      # on `dial unix ///run/podman/podman.sock: no such file or directory`,
      # while .58 booted from the identical image and was fine — because the
      # cycle-breaking picks a victim arbitrarily.
      #
      # Ordering before podman.socket buys nothing anyway: the socket only
      # listens. podman.service is what touches the storage, it is socket-
      # activated, and the thing that connects is Nomad — which is ordered after
      # this unit and cannot start without it.
      before = [
        "nomad.service"
        "podman.service"
      ];
      requiredBy = [ "nomad.service" ];

      # wantedBy multi-user.target, though, so a node that fails this check
      # still finishes booting and is still reachable over SSH to be fixed.
      # Failing closed should cost the cluster a node, not an operator a drive
      # across town.
      wantedBy = [ "multi-user.target" ];

      # Both already in every NixOS closure — findmnt/mountpoint/mount from
      # util-linux, install from coreutils — so this adds nothing to the RAM
      # budget of the netboot image.
      path = with pkgs; [
        util-linux
        coreutils
        # for the `nomad config validate` gate below — the check that catches a
        # fragment Nomad cannot parse before Nomad is asked to parse it.
        nomad
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        set -euo pipefail

        # THE GATE. `findmnt --target` reports the filesystem actually backing a
        # path, walking up to the nearest mountpoint — so this answers the
        # question that matters ("is what I am about to write to durable?")
        # rather than the proxy question ("did a mount unit succeed?").
        #
        # It gets every case right without being told which case it is in:
        #   - netbooted, disk mounted    -> ext4       -> proceed
        #   - netbooted, disk missing    -> tmpfs (/)  -> refuse
        #   - disk-booted .5, no label   -> ext4 (/)   -> proceed, no volumes
        #   - /data does not exist       -> ""         -> refuse
        #
        # The empty case is the one an earlier draft got wrong in the other
        # direction, and it is why `|| true` is here and the check is on the
        # value rather than on findmnt's exit status: an unreadable answer must
        # land in the refuse branch, never skip past it.
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

        # ${volumeRoot} is the marker that says "this disk carries the cluster's
        # stateful services". It is created once, by the disk-prep runbook, and
        # travels with the disk. Its absence is how 192.168.0.5 declares nothing
        # without appearing in any list.
        #
        # Note that this branch is NOT the fail-open one that was removed. It is
        # reached only after the gate above has proved ${mountPoint} durable, so
        # the worst it can produce is a node with no volumes — jobs stay pending
        # and visibly so. The removed branch could produce a node with volumes
        # backed by RAM.
        # Start from an empty directory every boot. Nothing carries over from a
        # previous boot's judgement about what was durable.
        rm -rf ${fragmentDir}
        install -d -m 0755 ${fragmentDir}

        # No ${volumeRoot} at all: this disk does not carry the cluster's
        # stateful services. Declare nothing and say so. Reached only after the
        # gate proved ${mountPoint} durable, so the worst case is a node with no
        # volumes — jobs stay pending, visibly.
        if [ ! -d ${volumeRoot} ]; then
          echo "no ${volumeRoot} on this disk — declaring no host volumes."
          echo "(mkdir ${volumeRoot}/<name> on the box that holds the data.)"
          exit 0
        fi

        declared=""
        ${installFragments}

        # A directory under ${volumeRoot} with no matching entry in
        # services.nomadStorage.volumes is almost certainly a typo in a runbook,
        # and silently ignoring it is how a volume ends up never declared.
        for d in ${volumeRoot}/*/; do
          [ -e "$d" ] || continue
          n=$(basename "$d")
          case " ${lib.concatStringsSep " " (lib.attrNames cfg.volumes)} " in
            *" $n "*) ;;
            *) echo "WARNING: ${volumeRoot}/$n exists but is not declared in services.nomadStorage.volumes — ignoring." >&2 ;;
          esac
        done

        # THE CHECK THAT WOULD HAVE CAUGHT D1. Well-formed JSON was never the
        # risk; Nomad-parseable config was. Validate before Nomad is allowed to
        # start, so a bad fragment fails HERE, loudly, instead of putting
        # nomad.service into a restart loop.
        if ! nomad config validate /etc/nomad.json ${fragmentDir} >/dev/null 2>&1; then
          echo "REFUSING to start Nomad: generated host-volume config does not validate." >&2
          nomad config validate /etc/nomad.json ${fragmentDir} >&2 || true
          rm -rf ${fragmentDir}
          exit 1
        fi

        echo "declared host volumes:''${declared:- (none)}"
      '';
    };

    # THE SECOND, INDEPENDENT FAIL-CLOSED LAYER, and the reason this is worth a
    # separate comment: `nomad agent -config=<missing file>` EXITS rather than
    # warning and carrying on — verified on this cluster. So even if the unit
    # above were masked, deleted, or somehow skipped, Nomad still cannot come up
    # having quietly forgotten its volumes; it comes up not at all. Combined
    # with fragmentDir living in tmpfs, "the directory exists" is equivalent to
    # "this boot proved the storage durable", and there is no third state.
    services.nomad.extraSettingsPaths = [ fragmentDir ];

    # Nomad's own StateDirectory= would otherwise re-open the bind-mounted
    # state directory to 0755 on every start. It holds the secret id and the
    # Variables keyring.
    systemd.services.nomad.serviceConfig.StateDirectoryMode = "0700";
  };
}
