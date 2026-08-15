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
    ../../module/linear-agent.nix
    ../../module/tailscale-funnel.nix
  ];

  services.linearAgent.enable = true;
  services.tailscaleFunnel = {
    enable = true;
    target = "3456";
  };

  # module path has no --argstr to supply disks.nix's `device`; pin the default (inert on the running system).
  _module.args.device = "/dev/sda";

  # EC2-style empty hostname; derive-hostname below sets ip-a-b-c-d from the DHCP IPv4.
  networking.hostName = "";

  # Legacy BIOS/GRUB (OptiPlex only netboots in legacy mode). disko installs GRUB onto disks.nix's EF02 partition — don't set grub.device.
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

  # Transient hostname ip-a-b-c-d from the primary LAN IPv4; runs before nomad/avahi so the node registers under it.
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
