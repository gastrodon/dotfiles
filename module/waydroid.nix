{ config, pkgs, ... }:
{
  virtualisation.waydroid.enable = true;

  boot.kernelModules = [ "binder_linux" ];

  environment.systemPackages = with pkgs; [
    android-tools
    lxc
    iptables
  ];

  security.sudo.extraRules = [
    {
      users = [ config.identity.username ];
      commands = [
        {
          command = "${pkgs.waydroid}/bin/waydroid";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  networking.firewall.allowedTCPPorts = [ 8080 ];
  networking.firewall.trustedInterfaces = [ "lxcbr0" ];
}
