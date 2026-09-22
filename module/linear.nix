# linear-cli — opt-in per host, same shape as claude-code.nix. Eva's own personal API
# key from linear.app/settings/account/security, fetched from the claude/ Bao ring
# (module/home-manager/bao-kv-get.nix) via the same claude-mcp AppRole claude-code.nix
# already delivers a secret_id for — depends on that module being imported too.
{ config, ... }:
{
  home-manager.users.${config.identity.username}.imports = [
    ./home-manager/linear.nix
  ];
}
