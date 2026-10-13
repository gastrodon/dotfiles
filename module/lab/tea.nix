# tea (Gitea CLI) — opt-in per host, same shape as linear.nix. Depends on
# claude-code.nix being imported too, for the gitea_approle_secret_id sops
# secret that module/home-manager/git.nix's credential helper already reads.
{ config, ... }:
{
  home-manager.users.${config.identity.username}.imports = [
    ./home/tea.nix
  ];
}
