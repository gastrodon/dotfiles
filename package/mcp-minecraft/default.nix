{ pkgs, lib, ... }:

pkgs.buildGoModule {
  pname = "mcp-minecraft";
  version = "0.1.0";

  src = ./.;

  vendorHash = "sha256-69RjvFm4byW1z4qjzTRhppJFjo6K0bgiCrVcwqtnb6s=";

  meta = with lib; {
    description = "MCP server exposing Prism Launcher Minecraft instance state (recipes, chat, screenshots) with integrated Litematica and Sponge WorldEdit schematic libraries";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "mcp-minecraft";
  };
}
