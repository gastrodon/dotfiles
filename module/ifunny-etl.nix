# Server-side system config for the iFunny ETL infra jobs (see
# ~/code/ifunny/etl/nomad/). The pipelines + their infra (mysql, rabbitmq,
# registry, adminer) run as podman tasks under Nomad with host networking, so
# the ports below are the host's own ports and the /data dirs are bind-mounted
# straight into the containers.
#
# This lives in dotfiles (not the etl flake) so the etl repo stays a purely
# local build/deploy/interact toolkit with no system-config coupling: edit
# ports here and `nixos-rebuild switch --flake .#server`, no cross-repo rev bump.
{ ... }:
{
  # Host-net container ports, opened on the LAN so the broker/UIs/registry/db
  # are reachable at server:<port>. amqp/mysql/registry are unauthenticated —
  # fine for a trusted home network only.
  networking.firewall.allowedTCPPorts = [
    5672 # rabbitmq amqp
    15672 # rabbitmq management UI
    8080 # adminer
    3306 # mysql
    5000 # container registry
  ];

  # Bulk storage on the 11 TB /data volume, bind-mounted by the podman jobs.
  # Ownership matches each image's runtime uid (rootful podman maps container
  # uids straight through); registry:2 and adminer run as root.
  systemd.tmpfiles.rules = [
    "d /data/ifunny          0755 root root -"
    "d /data/ifunny/mysql    0700 999  999  -"
    "d /data/ifunny/rabbitmq 0755 999  999  -"
    "d /data/ifunny/registry 0755 root root -"
  ];

  # The in-cluster registry (nomad/registry.nomad.hcl) serves plain HTTP on
  # localhost:5000; rootful podman refuses non-TLS registries unless they're
  # explicitly marked insecure, so the pipeline jobs' localhost:5000/ifunny/
  # <file> pulls would otherwise fail.
  virtualisation.containers.registries.insecure = [ "localhost:5000" ];
}
