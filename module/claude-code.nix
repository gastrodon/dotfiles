# "claude-code local development" capability — import on hosts where eva runs `claude` (stone, twink).
# Wires the home-manager claude.nix.
# Also installs Claude Desktop + Cowork's VM sandbox (EVA-592).
{
  config,
  pkgs,
  claude-desktop-nix,
  ...
}:
{
  imports = [ claude-desktop-nix.nixosModules.default ];

  # nmcbride/claude-desktop-nix wires Cowork's FHS probes via tmpfiles symlinks.
  programs.claude-desktop = {
    enable = true;
    cowork.kvmUsers = [ config.identity.username ];
  };

  users.users.claude = {
    isNormalUser = true;
    description = "Claude Code agent";
    shell = pkgs.bash;
  };
  users.users.claude.extraGroups = [ "devs" ];

  # Where the lab profiles read the approle secret ids.
  passage.secrets = {
    CLAUDE_APPROLE_GITEA = {
      path = "/run/secrets/bao/gitea_approle_secret_id";
      owner = config.identity.username;
    };
    CLAUDE_APPROLE_MCP = {
      path = "/run/secrets/bao/claude_mcp_approle_secret_id";
      owner = config.identity.username;
    };
  };

  home-manager.users.${config.identity.username}.imports = [
    ./home-manager/claude.nix
  ];
}
