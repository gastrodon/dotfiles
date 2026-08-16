# pi + pi-black — opt-in per host, same shape as claude-code.nix. No sops secrets: auth is
# interactive-only (see module/home-manager/pi.nix).
{ config, ... }:
{
  home-manager.users.${config.identity.username}.imports = [
    ./home-manager/pi.nix
  ];
}
