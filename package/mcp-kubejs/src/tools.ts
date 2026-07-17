export interface ToolDef {
  description: string;
  /** JSON Schema for the tool's arguments. */
  inputSchema: Record<string, unknown>;
  /**
   * Run on the game thread via MinecraftServer.executeBlocking. Required
   * for anything touching world state. Keep handlers fast (<40ms) — they
   * block a server tick while running.
   */
  onGameThread?: boolean;
  /** Return a string (sent as-is) or any JSON-serializable value. */
  run(args: Record<string, unknown>): unknown;
}

export const TOOLS: Record<string, ToolDef> = {
  ping: {
    description: "Liveness check for the KubeJS MCP server; returns 'pong'.",
    inputSchema: { type: "object", properties: {} },
    run: () => "pong",
  },

  game_info: {
    description:
      "Basic live world info: players online, overworld game time and day time.",
    inputSchema: { type: "object", properties: {} },
    onGameThread: true,
    run: () => {
      const server = Utils.server;
      const overworld = server.overworld();
      return {
        players_online: Number(server.getPlayerList().getPlayerCount()),
        game_time: Number(overworld.getGameTime()),
        day_time: Number(overworld.getDayTime()),
      };
    },
  },
};
