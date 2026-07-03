{ ... }:
{
  imports = [
    ../../module/cluster-net.nix
  ];

  networking.hostName = "rpi4b";
  clusterNet.address = "192.168.0.242";
  services.nomadClient.datacenter = "home";
}
