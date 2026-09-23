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
    ../../module/avahi.nix
    ../../module/nomad-server.nix
    ../../module/minecraft-server.nix
    ../../module/actual.nix
    ../../module/tailscale-funnel.nix
    ../../module/home-assistant.nix
    ../../module/ollama.nix
    ../../module/testbench-web.nix
    # Firewall + data directories for the Nomad jobs that now live in
    # ~/code/home-infra. See that module's header for where the line between
    # the two repos is drawn and why.
    ../../module/cluster-services.nix
    # EC2-style ip-a-b-c-d hostname, and the NetworkManager setting that stops
    # it being overruled (EVA-192). Shared with the netboot node so the two
    # cannot drift.
    ../../module/derive-hostname.nix
    # The /data disk and the Nomad host volumes on it (EVA-302). Shared with
    # module/cluster-node.nix for the same reason as derive-hostname above:
    # this configuration is also built as `server-netboot`, so the disk-booted
    # and RAM-booted forms of the same host must agree about what counts as
    # durable storage.
    ../../module/nomad-storage.nix
  ];

  # 192.168.0.5 keeps its 120 GB SSD and stays the disk-bootable fallback, so
  # it has no disk labelled `nomad-data` and never will. It still enables this:
  # /data there is an ordinary directory on the root ext4, which passes the
  # durability gate, and it carries no /data/volumes, so it declares no host
  # volumes and hosts no stateful jobs. Nothing about that outcome is written
  # down per box — see module/nomad-storage.nix for why that matters.
  services.nomadStorage.enable = true;

  # The testbench 3D viewer. The job serves a directory; the page itself
  # is pushed into it from the testbench repo (`nix run .#deploy`), so
  # publishing a new model never touches this host's configuration.
  services.testbenchWeb = {
    enable = true;
    # 8443, not 443: kept off the default Funnel port so it doesn't collide
    # with anything else that later claims 443 on this host. Nothing is
    # public until this host is rebuilt.
    #
    # This page has no authentication. Set to null to keep it tailnet+LAN
    # only, which is what it was before.
    funnelPort = 8443;
  };

  # Backs the rpi4b kiosk (hosts/rpi/graphical.nix points Firefox at homeassistant.local:8123).
  services.homeAssistantJob.enable = true;

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

  # module path has no --argstr to supply disks.nix's `device`; pin the default (inert on the running system).
  _module.args.device = "/dev/sda";

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
