# Shared config for the Obsidian Local REST API plugin's MCP server.
# apiKey only authenticates loopback traffic on this box — not an eva-ring secret, so it's a plain committed value.
{
  apiKey = "504b379b-827b-4fdb-9b3b-839d9282a35a";
  port = 27123;
  url = "http://127.0.0.1:27123/mcp/";
}
