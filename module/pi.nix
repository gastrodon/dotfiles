# pi + pi-black — opt-in per host, same shape as claude-code.nix. Auth itself stays
# interactive-only (see module/home-manager/pi.nix); the one sops secret here is the
# brave-search skill's API key, claude's own, so it's in-ring (secrets.claude.yaml).
{ config, ... }:
{
  home-manager.users.${config.identity.username}.imports = [
    ./home-manager/pi.nix
  ];

  # Brave Search API key, consumed by the pi-skills brave-search skill (see
  # module/home-manager/pi.nix). Free-tier key from api-dashboard.search.brave.com.
  # Value must be added to secrets.claude.yaml (`sops secrets.claude.yaml`, key
  # brave/api_key) before this host can activate the pi module.
  sops.secrets."brave/api_key" = {
    sopsFile = ../secrets.claude.yaml;
    key = "brave/api_key";
    format = "yaml";
    owner = config.identity.username;
    mode = "0600";
  };
}
