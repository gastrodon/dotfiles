# Tailscale client: joins the tailnet. Tailscale SSH is opt-in: it bypasses sshd and authorized_keys.
{
  config,
  lib,
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
      authKeyFile = config.passage.secrets.TAILSCALE_AUTH_KEY.path;
      # LAN DNS is blocky via DHCP (EVA-551); MagicDNS would forward to a stale upstream instead.
      extraSetFlags = [
        "--accept-dns=false"
        "--ssh=${lib.boolToString cfg.ssh}"
      ];
    };

    passage.secrets.TAILSCALE_AUTH_KEY.restartUnits = [ "tailscaled-autoconnect.service" ];

    # Skipped until passage-sync has put the key on disk.
    systemd.services.tailscaled-autoconnect.unitConfig.ConditionFileNotEmpty =
      config.passage.secrets.TAILSCALE_AUTH_KEY.path;
  };
}
