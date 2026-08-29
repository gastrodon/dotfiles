# Server - Machine-specific configuration
{
  config,
  lib,
  pkgs,
  ...
}:
let
  hosts = import ../../module/hosts.nix;
in
{
  imports = [
    ./hardware-configuration.nix
    ./disks.nix
    ../../module/claude-user.nix
    ../../module/avahi.nix
    ../../module/nomad-server.nix
    ../../module/minecraft-server.nix
    ../../module/actual.nix
    ../../module/pibot.nix
    ../../module/tailscale-funnel.nix
    ../../module/ci-deploy.nix
    ../../module/home-assistant.nix
    ../../module/ollama.nix
  ];

  # Backs the rpi4b kiosk (hosts/rpi/graphical.nix points Firefox at homeassistant.local:8123).
  services.homeAssistantJob.enable = true;

  services.tailscaleFunnel = {
    enable = true;
    target = "3456";
  };

  # Nomad owns the CPU-only Ollama service and its persistent model volume. Pin
  # the host-networked job to server1 so the worker has a stable endpoint.
  services.ollamaJob = {
    enable = true;
    nodeAddress = hosts.server1;
    models = [
      "granite3.3:2b"
      "qwen2.5-coder:1.5b"
      "qwen2.5:1.5b"
      "qwen3:1.7b"
      "llama3.2:1b"
      "qwen2.5-coder:7b"
    ];
  };

  # Ollama stays opt-in for pibot while the CPU candidates are being measured.
  # Keep provider=anthropic as default until EVA-196 (tool-calling) is resolved.
  services.piAgent = {
    provider = "anthropic";
    model = "claude-sonnet-5";
    thinkingLevel = "high";
    ollama = {
      enable = true;
      baseUrl = "http://${hosts.server1}:11434/v1";
      model = "qwen2.5-coder:7b";
    };
  };

  services.linearAgent = {
    defaultModel = "anthropic/claude-sonnet-5";
    allowedModels = [
      "anthropic/claude-sonnet-5"
      "ollama/granite3.3:2b"
      "ollama/qwen2.5-coder:7b"
    ];
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
