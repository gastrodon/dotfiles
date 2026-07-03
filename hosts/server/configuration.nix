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
  ];

  networking.hostName = "server";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelModules = [ "i915" ];

  services.upower.enable = false;
  services.udev.extraRules = "";

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [ intel-vaapi-driver ];
  };

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

  # Clone dotfiles on first boot if /etc/nixos has no git repo
  systemd.services.clone-dotfiles = {
    description = "Clone dotfiles to /etc/nixos";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    unitConfig.ConditionPathExists = "!/etc/nixos/.git";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ pkgs.git ];
    script = ''
      rm -rf /etc/nixos
      git clone https://github.com/gastrodon/dotfiles /etc/nixos
    '';
  };

  # Nightly: pull, switch, gc
  systemd.timers.nightly-update = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };

  systemd.services.nightly-update = {
    description = "Nightly NixOS update";
    after = [
      "network-online.target"
      "clone-dotfiles.service"
    ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      WorkingDirectory = "/etc/nixos";
      Environment = "NIXPKGS_ALLOW_UNFREE=1";
    };
    path = with pkgs; [
      git
      nixos-rebuild
      nix
    ];
    script = ''
      git pull
      nixos-rebuild switch --flake .#server --impure
      nix-collect-garbage -d
    '';
  };
}
