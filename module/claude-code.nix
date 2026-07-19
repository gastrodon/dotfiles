# NixOS module for the "claude-code local development" capability. Import from
# hosts where eva runs `claude` interactively (stone, twink). Wires up:
#   - the home-manager module that installs the `claude`/`claude-email` binaries
#     and MCP server wrappers
#   - the sops.secrets that those wrappers consume, all from secrets.yaml
#
# Hosts that don't import this module (server, rpis) never try to decrypt
# secrets.yaml, which they aren't recipients of.
{ config, ... }:
{
  home-manager.users.${config.identity.username}.imports = [
    ./home-manager/claude.nix
  ];

  sops.secrets."github/mcp-token".owner = config.identity.username;
  sops.secrets."obsidian/api-key".owner = config.identity.username;
  sops.secrets."email/address".owner = config.identity.username;
  sops.secrets."email/password".owner = config.identity.username;

  # AWS secret access key — eva-only (secrets.yaml, out of ring).
  sops.secrets."aws/iam_secret".owner = config.identity.username;

  # AWS access key id — claude's own non-secret identifier, sourced from
  # secrets.claude.yaml to keep it on the in-ring side of the split.
  sops.secrets."aws/iam_key" = {
    sopsFile = ../secrets.claude.yaml;
    key = "aws/iam_key";
    format = "yaml";
    owner = config.identity.username;
    mode = "0600";
  };
}
