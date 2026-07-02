{ config, pkgs, ... }:
{
  virtualisation.waydroid.enable = true;
  # Use waydroid-nftables to support NixOS's default nftables firewall
  # (plain waydroid's iptables rules silently fail on nftables systems)
  virtualisation.waydroid.package = pkgs.waydroid-nftables;

  # Required kernel modules for LXC containers
  boot.kernelModules = [
    "ashmem_linux"
    "binder_linux"
  ];

  environment.systemPackages = with pkgs; [
    waydroid-nftables
    waydroid-helper
    android-tools
    lxc
    nftables
    wl-clipboard
  ];

  security.sudo.extraRules = [
    {
      users = [ config.identity.username ];
      commands = [
        {
          command = "${pkgs.waydroid-nftables}/bin/waydroid";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # Network configuration for proxy access (MITM capture, etc.)
  networking.firewall.allowedTCPPorts = [ 8080 ];
  networking.firewall.trustedInterfaces = [ "lxcbr0" ];
}
