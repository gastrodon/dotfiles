# linear-cli — opt-in per host, same shape as claude-code.nix. Unlike the server-side Linear
# agent (gastrodon/pibot, wired in via module/pibot.nix; OAuth app credentials),
# this is eva's own personal API key from linear.app/settings/account/security,
# so it stays owner-eva 0400 and is never handed to a claude-scoped module.
{ config, ... }:
{
  sops.secrets."linear/api_key" = {
    owner = config.identity.username;
    mode = "0400";
  };

  home-manager.users.${config.identity.username}.imports = [
    ./home-manager/linear.nix
  ];
}
