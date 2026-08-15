# System config for the iFunny ETL infra jobs (pipelines live in ~/code/ifunny/etl/nomad/).
{ ... }:
{
  # Host-net container ports on the LAN. amqp/mysql/registry unauthenticated — trusted home net only.
  networking.firewall.allowedTCPPorts = [
    5672 # rabbitmq amqp
    15672 # rabbitmq management UI
    8080 # adminer
    3306 # mysql
    5000 # container registry
  ];

  # /data ownership matches each image's runtime uid (rootful podman maps uids through); registry/adminer are root.
  systemd.tmpfiles.rules = [
    "d /data/ifunny          0755 root root -"
    "d /data/ifunny/mysql    0700 999  999  -"
    "d /data/ifunny/rabbitmq 0755 999  999  -"
    "d /data/ifunny/registry 0755 root root -"
  ];

  # rootful podman refuses non-TLS registries; the in-cluster registry serves plain HTTP here.
  virtualisation.containers.registries.insecure = [ "localhost:5000" ];
}
