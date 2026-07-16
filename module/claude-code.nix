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
}
