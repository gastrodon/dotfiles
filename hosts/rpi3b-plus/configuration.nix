{ ... }:
{
  imports = [
    ../../module/cluster-net.nix
  ];

  networking.hostName = "rpi3b-plus";
  clusterNet.address = "192.168.0.241";
  services.nomadClient.datacenter = "home";
}
