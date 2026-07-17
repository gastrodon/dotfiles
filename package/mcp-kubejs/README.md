# mcp-kubejs — MCP server inside the Minecraft JVM

A TypeScript-authored [MCP](https://modelcontextprotocol.io/) server that
runs *inside* KubeJS on the Create+ server. It compiles to a single
Rhino-compatible JS bundle (`mcp_server.js`) that lives in
`kubejs/server_scripts/`, boots an HTTP server in the game JVM, and serves
MCP tools with direct access to live world state. No external processes,
no bridge files, no custom transport daemons.

## Interface

**Endpoint:** `POST http://server.local:25580/mcp`

**Transport:** MCP Streamable HTTP, simplified:

- Request: JSON-RPC 2.0 message (or batch) as the POST body.
- Response: `200` with a plain JSON body (single message or batch).
  No SSE — every response is a complete JSON document.
- Notifications-only input: `202 Accepted`, empty body.
- `GET /mcp` and `DELETE /mcp` are not registered (405). There is no
  server→client stream and no session state; every POST is independent.

**Protocol methods handled:** `initialize`, `ping`, `tools/list`,
`tools/call`. Unknown notifications are silently accepted; unknown
requests get `-32601`.

**Claude Code config** (on the player's machine):

```json
{
  "mcpServers": {
    "minecraft": {
      "type": "http",
      "url": "http://server.local:25580/mcp"
    }
  }
}
```

**Auth:** none. The endpoint binds `0.0.0.0` but the host only exists on
the home LAN (no WAN exposure — see `module/minecraft-server/default.nix`).
Anyone on the LAN can call tools; that is the accepted trust model.

## Tools

| Tool | Description |
|---|---|
| `ping` | Liveness check; returns `pong`. |
| `game_info` | Players online, overworld game time and day time. |

Tools are defined in `src/tools.ts` as a flat `TOOLS` record. Each tool
declares a JSON Schema for its args and a synchronous `run` function. Set
`onGameThread: true` for anything touching world state — the dispatcher
marshals the call onto the server thread via
`MinecraftServer.executeBlocking` and blocks the HTTP handler thread until
it completes. Keep game-thread handlers under ~40ms; they block a tick.

## Architecture

```
Claude Code (stone)
  │  MCP Streamable HTTP (plain JSON POST)
  ▼
tinyserver HTTPServer :25580          ── handler thread
  │  handlePost() → JSON-RPC dispatch     (src/mcp.ts)
  │  executeBlocking() for world tools
  ▼
MinecraftServer game thread           ── world state access
```

Why this works: the KubeJS class filter denies `java.net`/`java.nio` (no
raw sockets from scripts), but `dev.latvian.apps.tinyserver.*` — an HTTP
server library jarjar'd inside the KubeJS jar — is default-allowed and
fully script-reachable. The script owns its own `HTTPServer` instance;
the filter only gates what the *script* references, not what tinyserver's
internals use.

Why hand-rolled protocol: the official MCP SDK is Promise-saturated and
Rhino has no event loop. The server side of MCP is small (four methods);
sync dispatch covers it in ~150 lines (`src/mcp.ts`).

## Build

Nix derivation (`default.nix`): `tsc --noEmit` type-check, then
`esbuild --bundle --format=iife --target=es2015` → `$out/mcp_server.js`.
The minecraft-server module symlinks that into the server's
`kubejs/server_scripts/`.

Dev loop:

1. Edit `src/*.ts`, run `./build server` at repo root.
2. eva applies via `nixos-rebuild switch` on `server`.
3. In-game or via console: `/kubejs reload server_scripts` — the bundle
   stops the previous HTTP server (handle stashed in KubeJS `global`)
   and rebinds. No JVM restart needed.

## Files

```
src/main.ts      tinyserver boot, reload lifecycle, /mcp route
src/mcp.ts       JSON-RPC 2.0 + MCP protocol core, game-thread marshalling
src/tools.ts     tool definitions (add tools here)
src/kubejs.d.ts  ambient declarations for the Rhino/KubeJS runtime
```

Full game typings can come later from a ProbeJS dump (`/probejs dump` on
a client instance); until then `kubejs.d.ts` declares only the surface we
touch, mostly as `any`.

See `CLAUDE.md` for Rhino authoring constraints and Java interop notes.
