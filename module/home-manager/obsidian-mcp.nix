# Shared config for the Obsidian Local REST API plugin's built-in MCP server.
#
# The apiKey is a purely local, arbitrary value: it only authenticates
# loopback traffic between the Obsidian plugin and Claude Code on this one
# machine. It is not a secret in the eva-ring sense — nothing outside this box
# can reach the endpoint — so it lives as a plain committed value in the nix
# store and is wired verbatim into both the plugin's data.json (as `apiKey`)
# and the MCP client's Authorization header.
{
  apiKey = "504b379b-827b-4fdb-9b3b-839d9282a35a";
  port = 27123;
  url = "http://127.0.0.1:27123/mcp/";
}
