# Tailscale client: joins the tailnet. Tailscale SSH is opt-in: it bypasses sshd and authorized_keys.
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
      default = false;
      description = "Accept Tailscale SSH connections from other tailnet nodes.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      openFirewall = true;
      authKeyFile = config.sops.secrets."tailscale/auth_key".path;
      # LAN DNS is blocky via DHCP (EVA-551); MagicDNS would forward to a stale upstream instead.
      extraSetFlags = [
        "--accept-dns=false"
        "--ssh=${lib.boolToString cfg.ssh}"
      ];
    };

    sops.secrets."tailscale/auth_key" = { };
  };
}
