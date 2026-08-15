# Host → LAN IP mapping. Single source of truth for anywhere we need to reach
# one of our own machines: eva's ssh matchBlocks, MCP wrappers, etc.
{
  stone = "192.168.0.77";
  # OptiPlex server boxes — current router leases, not yet DHCP-reserved (may shift).
  server1 = "192.168.0.58";
  server2 = "192.168.0.17";
  twink = "192.168.0.122";
}
