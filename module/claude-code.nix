# "claude-code local development" capability — import on hosts where eva runs `claude` (stone, twink).
# Wires the home-manager claude.nix + the sops.secrets its MCP wrappers consume. Hosts that skip it never decrypt secrets.yaml.
{ config, ... }:
{
  home-manager.users.${config.identity.username}.imports = [
    ./home-manager/claude.nix
  ];

  sops.secrets."github/mcp-token".owner = config.identity.username;
  sops.secrets."email/address".owner = config.identity.username;
  sops.secrets."email/password".owner = config.identity.username;

  # AWS secret access key — eva-only (secrets.yaml, out of ring).
  sops.secrets."aws/iam_secret".owner = config.identity.username;

  # AWS access key id — claude's own identifier, from secrets.claude.yaml (in-ring).
  sops.secrets."aws/iam_key" = {
    sopsFile = ../secrets.claude.yaml;
    key = "aws/iam_key";
    format = "yaml";
    owner = config.identity.username;
    mode = "0600";
  };
}
