# tea (Gitea CLI) - opt-in per host. Needs claude-code.nix for the claude_mcp secret_id bao-kv-get reads.
{ config, ... }:
{
  home-manager.users.${config.identity.username}.imports = [
    ./home/tea.nix
  ];
}
