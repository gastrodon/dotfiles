# Shared base for the OptiPlex cluster nodes (EVA-299).
#
# THE POINT OF THIS MODULE IS WHAT IT LEAVES OUT. These nodes are meant to
# netboot and run entirely from RAM (EVA-298), so the closure is not a matter
# of taste — it is the hard budget. Measured before this module existed, the
# `server` configuration (hosts/shared.nix + hosts/server/configuration.nix)
# closed over **18.1 GiB**: steam, i3, X11, the font set, pipewire, Home
# Assistant, the Minecraft server, the graphical stack. The smallest box in the
# fleet (192.168.0.5) has **7.7 GiB of RAM total**. An 18 GiB image cannot be
# made to boot on it by tuning compression; the graphical stack has to not be
# there at all.
#
# So this deliberately does NOT import hosts/shared.nix. Anything a headless
# scheduler node genuinely needs is listed here explicitly, and every addition
# is a withdrawal from the RAM budget that workloads also draw on.
#
# What lives here vs. elsewhere, after the Phase 2 split: this module owns
# host/OS-level facts only — the container runtime, the scheduler daemon, the
# users, the secret material, the firewall. Nomad *job* definitions live in
# ~/code/home-infra and are pushed with `nomad job run`, not baked into a
# system closure. A stateless node cannot provision itself, which is precisely
# why the job specs had to stop living in a NixOS module.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.clusterNode;
in
{
  imports = [
    ./identity.nix
    ./users.nix
    ./claude-user.nix
    ./podman.nix
    ./nomad-server.nix
    ./sops.nix
    ./derive-hostname.nix
    # The data disk, and the gate that stops Nomad starting with host volumes
    # backed by RAM. Shared with hosts/server/configuration.nix so the
    # disk-booted and netbooted halves of the fleet cannot drift on the one
    # question a netbooted node most needs answered correctly.
    ./nomad-storage.nix

    # The service ports the cluster's jobs listen on. Netbooted nodes were
    # missing this entirely, and the symptom was not an error: on 2026-09-10
    # traefik, mysql, rabbitmq and ollama all reported healthy on .17/.58 while
    # answering nothing from off-box, because the lean image opened only
    # 22/4646/4647/4648. Ingress was down and every job looked fine.
    #
    # Safe to share with the disk-booted form now that this module carries no
    # tmpfiles rules for /data — see the note in it for why those were a
    # data-loss hazard rather than a convenience.
    ./cluster-services.nix
  ];

  options.services.clusterNode = {
    diskless = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        This node netboots and has no OS on disk. Drops the bootloader (there
        is nothing to install it onto) and stops sops from looking for an SSH
        host key that a RAM-booted node regenerates on every boot.

        Leave false for a node still booting off its SSD — the same module
        then describes a conventional install, so the two can be compared and
        migrated one box at a time rather than in a flag day.
      '';
    };

    ageKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Age identity used to decrypt sops secrets, for diskless nodes.

        A netbooted node has no persistent identity: /etc/ssh/ssh_host_ed25519_key
        is regenerated into tmpfs on every boot, so the default
        `sops.age.sshKeyPaths` route (module/sops.nix) cannot work — the key
        that the secrets were encrypted to is gone the moment the box reboots.

        SECURITY TRADEOFF, STATED PLAINLY: setting this embeds a private key in
        the netboot image, and that image is served over plain HTTP to anything
        on the LAN that asks. Today, reading cluster secrets needs root on a
        box; with this set, it needs a LAN cable. That is a real reduction in
        the blast radius of the home network, and it should be a deliberate
        choice rather than a side effect of turning on netboot.

        Left null by default so the image builds and boots without secrets. A
        node that cannot decrypt secrets still joins Nomad and runs jobs; what
        it loses is the ACL bootstrap token and the Tailscale auth key.
      '';
    };
  };

  config = lib.mkMerge [
    {
      networking.useDHCP = lib.mkDefault true;

      # Enabled on every cluster node, including the ones with no data disk.
      # A node without one declares no volumes and hosts no stateful jobs;
      # that outcome is reached by looking at the disk, not by naming the box
      # here, which is what keeps one image serving all three. See
      # module/nomad-storage.nix.
      services.nomadStorage.enable = true;

      # Deliberately short. A cluster node is a place to run containers, not a
      # workstation — every package here is resident in RAM on a box that has
      # 7.7 GiB of it.
      environment.systemPackages = with pkgs; [
        curl
        git
        vim
        pciutils
        tmux

        # e2fsprogs is not optional on a node that mounts an ext4 data disk,
        # and its absence is not obvious until it bites. Two separate reasons:
        #
        #   1. `fsck.ext4`. NixOS generates a systemd-fsck@ unit for a
        #      fileSystems entry, and without the binary that unit fails —
        #      on a filesystem holding the cluster's only copy of its data.
        #   2. `mkfs.ext4` / `e2label` / `blkid`, for preparing a replacement
        #      disk *from the netbooted node itself*. That is not a corner
        #      case: there is one drive bay and one SATA power lead per box,
        #      so a new disk can only be formatted after it is fitted, which
        #      is after the old one is gone. The netbooted node is the only
        #      thing that can do it.
        #
        # Found the hard way on 2026-09-10: .17's 6 TB had to be formatted via
        # `nix build nixpkgs#e2fsprogs` on the running node because the image
        # had no mkfs. That worked, but it needs a network and a substituter at
        # exactly the moment the box has no disk — a bad thing to depend on.
        e2fsprogs
      ];

      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];

      services.openssh.enable = true;
      services.openssh.settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };

      networking.firewall.allowedTCPPorts = [ 22 ];

      time.timeZone = "America/New_York";
      i18n.defaultLocale = "en_US.UTF-8";

      powerManagement.cpuFreqGovernor = "performance";

      system.stateVersion = "25.11"; # DO NOT CHANGE
    }

    (lib.mkIf cfg.diskless {
      # Nothing to install a bootloader onto, and asking for one makes the
      # netboot build fail rather than merely producing dead weight.
      boot.loader.grub.enable = lib.mkForce false;

      # The store arrives as a squashfs in the initrd and everything writable
      # is tmpfs, so a nix GC on a running node would be reclaiming space it
      # does not own. Reboot is the garbage collector here.
      nix.gc.automatic = lib.mkForce false;

      # See ageKeyFile above: the SSH host key is regenerated on every boot, so
      # it can never be the identity secrets were encrypted to.
      sops.age.sshKeyPaths = lib.mkForce [ ];
      sops.age.keyFile = lib.mkForce (
        if cfg.ageKeyFile != null then toString cfg.ageKeyFile else "/run/cluster-node-age-key-absent"
      );

      # Make the state directory Nomad wants exist in tmpfs before it starts;
      # on a disk-booted node this is an ordinary directory that survives, and
      # a netbooted one has to be told to create it each boot.
      systemd.tmpfiles.rules = [
        "d /var/lib/nomad 0700 root root -"
        "d /var/lib/private 0700 root root -"
      ];
    })

    (lib.mkIf (!cfg.diskless) {
      # Legacy BIOS/GRUB — the OptiPlexes only netboot in legacy mode, and the
      # disk layout (hosts/server/disks.nix) has an EF02 partition, not an ESP.
      boot.loader.grub.enable = true;
    })
  ];
}
