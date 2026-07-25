# Bulk-storage provisioning for the iFunny ETL stack on the 11 TB /data LVM
# volume. The Nomad podman jobs bind-mount these paths (rootful podman maps
# container uids straight through, so ownership is set to each image's runtime
# uid):
#
#   /data/ifunny/mysql     MySQL datadir      (mysql:8.4 runs as uid 999)
#   /data/ifunny/rabbitmq  RabbitMQ mnesia    (rabbitmq:3.13 runs as uid 999)
#   /data/ifunny/registry  registry:2 blob store (docker distribution image
#                          store — pipeline images are pushed here by the build
#                          host and pulled by the Nomad jobs over localhost:5000)
{ config, ... }:
{
  systemd.tmpfiles.rules = [
    "d /data/ifunny          0755 root   root  -"
    "d /data/ifunny/mysql    0700 999    999   -"
    "d /data/ifunny/rabbitmq 0755 999    999   -"
    "d /data/ifunny/registry 0755 root   root  -"
  ];

  # The in-cluster registry (nomad/registry.nomad.hcl) serves plain HTTP on
  # localhost:5000. Podman (the nomad-driver-podman backend, running rootful)
  # refuses non-TLS registries unless they're explicitly marked insecure, so
  # the pipeline jobs' `localhost:5000/ifunny/<file>` pulls would otherwise
  # fail. It's a single-host, host-net-only registry — no TLS, no auth.
  virtualisation.containers.registries.insecure = [ "localhost:5000" ];
}
