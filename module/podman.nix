{
  config,
  pkgs,
  lib,
  ...
}:
{
  virtualisation.podman.enable = true;

  virtualisation.containers.policy = {
    default = [ { type = "insecureAcceptAnything"; } ];
  };

  environment.systemPackages = [ pkgs.podman-compose ];
}
