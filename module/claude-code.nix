# "claude-code local development" capability — import on hosts where eva runs `claude` (stone, twink).
# Wires the home-manager claude.nix + the sops.secrets its MCP wrappers consume. Hosts that skip it never decrypt secrets.yaml.
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

  home-manager.users.${config.identity.username}.imports = [
    ./home-manager/claude.nix
  ];

  sops.secrets."bao/gitea_approle_secret_id".owner = config.identity.username;
  sops.secrets."bao/claude_mcp_approle_secret_id".owner = config.identity.username;
}
