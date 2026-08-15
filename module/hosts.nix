# Host → LAN IP mapping. Single source of truth for anywhere we need to reach
# one of our own machines: eva's ssh matchBlocks, MCP wrappers, etc.
{
  stone = "192.168.0.77";
  # The two rebuilt OptiPlex server boxes (EVA-20 replacement). Current router
  # leases, not yet DHCP-reserved — will shift until reservations are set.
  # Runtime hostnames self-derive as ip-192-168-0-58 / ip-192-168-0-17.
  server1 = "192.168.0.58";
  server2 = "192.168.0.17";
  twink = "192.168.0.122";
}
