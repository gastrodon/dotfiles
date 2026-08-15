# Server - Machine-specific configuration
{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./disks.nix
    ../../module/claude-user.nix
    ../../module/avahi.nix
    ../../module/nomad-server.nix
    ../../module/minecraft-server.nix
    ../../module/actual.nix
  ];

  # disks.nix takes `device` as a module arg (so the disko CLI can override it
  # per box via --argstr at install time). On the installed-system module path
  # there's no CLI to supply it, so pin the default here; it's inert on the
  # running system (only the root mountpoint reaches the toplevel).
  _module.args.device = "/dev/sda";

  # EC2-style: no baked hostname. A boot service derives `ip-a-b-c-d` from the
  # DHCP-assigned IPv4 (see derive-hostname below), so one image serves every
  # box and each self-names from its (router-reserved) address.
  networking.hostName = "";

  # Legacy BIOS boot via GRUB. These boxes (Dell OptiPlex) only expose network
  # boot in legacy mode, so the installed system boots the same way — no
  # ESP/systemd-boot. disko installs GRUB onto the disk's EF02 partition, so the
  # target device comes from disks.nix, not a hardcoded path here.
  boot.loader.grub.enable = true;

  services.upower.enable = false;
  services.udev.extraRules = "";

  hardware.graphics.enable = true;

  services.xserver.videoDrivers = [ "modesetting" ];
  services.displayManager.defaultSession = "none+i3";

  powerManagement.cpuFreqGovernor = "performance";

  services.displayManager.autoLogin = {
    enable = true;
    user = config.identity.username;
  };

  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };

  # Derive a transient hostname from the primary LAN IPv4 (ip-192-168-0-243).
  # Runs once network is up and before nomad, so the node registers under its
  # IP-based name. Avahi then publishes <name>.local for discovery.
  systemd.services.derive-hostname = {
    description = "Set transient hostname from primary LAN IPv4";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    before = [
      "nomad.service"
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
    script = ''
      ip=$(ip -4 route get 1.1.1.1 \
        | awk '{ for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit } }')
      if [ -n "$ip" ]; then
        hostnamectl --transient set-hostname "ip-''${ip//./-}"
      fi
    '';
  };

  environment.systemPackages = with pkgs; [ pciutils ];

  desktop.extra.i3config = {
    assigns."1:" = [ { class = "XTerm"; } ];
    startup = [
      {
        command = "${pkgs.xterm}/bin/xterm -e ${pkgs.bottom}/bin/btm";
        notification = false;
      }
    ];
  };
}
