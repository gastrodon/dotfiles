# Nomad server — sole cluster leader. Single-server, no HA.
# Coordinates jobs across `home` (RPis) and `stone` datacenters.
{ pkgs, ... }:
{
  services.nomad = {
    enable = true;
    package = pkgs.nomad;
    dropPrivileges = false;
    enableDocker = false;
    extraPackages = [ pkgs.podman ];

    settings = {
      region = "global";
      datacenter = "home";

      server = {
        enabled = true;
        bootstrap_expect = 1;
      };

      client.enabled = false;
    };
  };

  networking.firewall.allowedTCPPorts = [
    4646
    4647
    4648
  ];
  networking.firewall.allowedUDPPorts = [ 4648 ];
}
