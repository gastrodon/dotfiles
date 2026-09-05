# Tailscale client: joins the tailnet with the shared claude auth key and
# enables Tailscale SSH by default, so any tailnet member reaches this host
# directly (`ssh <host>`) instead of hopping through a LAN-only box.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.tailscaleClient;
in
{
  options.services.tailscaleClient = {
    enable = lib.mkEnableOption "Tailscale client (joins the tailnet)";

    ssh = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Accept Tailscale SSH connections from other tailnet nodes.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      openFirewall = true;
      authKeyFile = config.sops.secrets."tailscale/auth_key".path;
      extraUpFlags = lib.optional cfg.ssh "--ssh";
    };

    sops.secrets."tailscale/auth_key" = {
      sopsFile = ../secrets.claude.yaml;
      format = "yaml";
    };
  };
}
