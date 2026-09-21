# Shared base for the OptiPlex cluster nodes (EVA-299).
#
# Deliberately does NOT import hosts/shared.nix — RAM budget. See wiki:
# Diskless netboot node image: design decisions.
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
        is nothing to install it onto).

        Leave false for a node still booting off its SSD — the same module
        then describes a conventional install, so the two can be compared and
        migrated one box at a time rather than in a flag day.
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

      # Workload-identity auth against infra/vault.nomad.hcl (EVA-303). Safe to
      # land ahead of Vault existing: measured 2026-09-09
      # (plans/01-vault-on-nomad.md) that a Nomad agent with this block pointed
      # at an unreachable address still starts and elects a leader normally —
      # jobs that declare a `vault {}` block just fail their template render
      # until Vault comes up, they don't take the agent down with them.
      #
      # `vault.policies` and per-job tokens do not exist any more — removed in
      # Nomad 1.10 along with the whole legacy token flow. This is not a
      # config choice, it's the only auth path this Nomad version has.
      services.nomad.settings.vault = {
        enabled = true;
        # IP, not a DNS name: this cluster derives hostnames from DHCP and the
        # address is the stable identity (EVA-192). Matches the constraint in
        # infra/vault.nomad.hcl -- update both together if the pin ever moves.
        address = "http://192.168.0.58:8200";
        jwt_auth_backend_path = "jwt-nomad";

        # Set once here so individual jobs don't each need their own
        # `identity { name = "vault_default" ... }` block.
        default_identity = {
          aud = [ "vault.io" ];
          ttl = "1h";
        };
      };

      # Deliberately short. A cluster node is a place to run containers, not a
      # workstation — every package here is resident in RAM on a box that has
      # 7.7 GiB of it.
      environment.systemPackages = with pkgs; [
        curl
        git
        vim
        pciutils
        tmux

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
