# CLAUDE.md — KubeJS/Rhino bridge scripts

These scripts run inside KubeJS on the Create+ server. KubeJS's JS engine is
**Mozilla Rhino** (version 2101.x for MC 1.21.1). Rhino is not V8 — the ES
support level and module story are different, and the whole thing runs inside
the Minecraft server JVM. Read this before editing anything under `bridge/`.

## Where scripts live and how they load

Three script contexts, three folders under the server's `kubejs/`:

| Folder | When it runs | What it can do |
|---|---|---|
| `startup_scripts/` | Once at JVM startup, before world load | Register blocks, items, fluids, block-entity builders. Cannot use `LevelEvents` (no world yet). |
| `server_scripts/` | Every world load; hot-reloadable via `/reload` or `/kubejs reload server_scripts` | Recipe changes, `ServerEvents`, `LevelEvents`, `BlockEvents`, tick handlers, `/execute` etc. **This is where the bridge lives.** |
| `client_scripts/` | Client-side only | Not applicable — server has no client. |

The bridge is a `server_scripts` file because it needs the live world.

## Rhino, ES support, and what NOT to write

Rhino 2101.x targets roughly **ES2017-** with some ES2020 additions. Safe to use:

- `let`, `const`
- Arrow functions
- Template literals
- Destructuring, spread/rest (both object and array)
- `for..of` loops
- Classes (basic — no `#private` fields)
- `Map`, `Set`, `Promise`

**Do not use:**
- `async` / `await` — Rhino's Promise support is incomplete; awaits will hang or throw
- ES modules — no `import` / `export`. Each file is a script, not a module. Cross-script sharing is via `global.foo = ...` or `globalThis` (KubeJS namespaces are cleaner; see below).
- `require()` — no CommonJS either
- npm packages — nothing in this environment. If you want a library, its code has to be pasted into the script.
- Optional chaining `?.` and nullish coalescing `??` — spotty support; use explicit `x != null ? x.y : ...`
- Private class fields `#foo` — use a `_foo` convention instead

When in doubt, target ES2017 syntax by hand. There is no transpiler in this
pipeline (yet — see `research/ponder-and-typescript.md` if that ever lands).

## Java interop is the whole point

Rhino gives us **direct access to Java classes**, which is how we reach Create
mod internals the KubeJS wiki does not document. Two idioms:

```js
// Preferred: named type binding
const BlockPos = Java.type("net.minecraft.core.BlockPos")
const pos = new BlockPos(10, 64, 10)

// Inline for one-shot use
const files = java.nio.file.Files.list(somePath)
```

Some things worth knowing about interop:

- **Java collections auto-wrap:** `List`s look like JS arrays, `Map`s look
  like JS objects. `for..of` works on `Iterable`. But `Array.isArray(javaList)`
  is `false` — don't rely on that check.
- **Java exceptions are catchable:** `catch (e) { e.javaException.printStackTrace() }`
- **Null vs undefined:** Java `null` comes through as JS `null`. Use `x == null`
  (double-equals) to cover both.
- **Rhino's `Java.type` caches** — safe to call at module top level; no perf cost.
- **Method overload resolution is heuristic.** If you get "no matching signature"
  errors, pass explicitly-typed args, e.g. `Java.to(myArray, "java.lang.Object[]")`.

## KubeJS API surface used here

The relevant events for a bridge script:

```js
ServerEvents.tick(event => {
  // Fires every server tick (20/sec). event.server is MinecraftServer.
  // Guard heavy work behind a counter — every 20 ticks = every second.
})

ServerEvents.loaded(event => {
  // Once, after the server finishes loading. Good for boot log lines.
})
```

Reaching a block in-world from a tick handler:

```js
ServerEvents.tick(event => {
  const server = event.server
  const level = server.overworld()             // ServerLevel
  const be = level.getBlockEntity(new BlockPos(x, y, z))
  // be is now a Java BlockEntity. Cast/interop as needed.
})
```

Executing a server command:

```js
event.server.runCommandSilent("say hello from kubejs")
```

Console/log output (goes to `logs/kubejs/server.log`, not `latest.log`):

```js
console.log("something happened")   // KubeJS logger, not JS's console
```

## Reaching Create internals

Create exposes its internals as plain Java classes. The kinetic base is
`com.simibubi.create.content.kinetics.base.KineticBlockEntity`, with:

- `.getSpeed()` — signed RPM at this shaft (float; negative = reverse)
- `.getTheoreticalSpeed()` — target RPM ignoring overstress
- `.calculateStressApplied()` — this block's SU draw
- `.getOrCreateNetwork()` — the shared `KineticNetwork` for this cluster,
  which has `.getCurrentStress()` and `.getCapacity()`

Rhino idiom:

```js
const KineticBE = Java.type("com.simibubi.create.content.kinetics.base.KineticBlockEntity")
const be = level.getBlockEntity(pos)
if (be instanceof KineticBE) {
  const rpm = be.getSpeed()
  const network = be.getOrCreateNetwork()
  const stress = network != null ? network.getCurrentStress() : 0
}
```

**Fragility warning:** these are private-ish Create implementation methods.
When Create updates, method names may rename silently — Rhino won't catch it
at parse time; you'll get a runtime NPE the first time the code hits the call.
Log defensively; test after every Create version bump.

## Reload workflow

- Edit `bridge/mcp_bridge.js` in the repo
- Run `./build` to verify Nix accepts the change
- eva applies via `nixos-rebuild switch` on `server` (out-of-ring, not us)
- In-game: `/kubejs reload server_scripts` — no restart needed
- If a tick handler was registered by the old script, it stays until a
  full server restart. This means during development you can end up with
  N copies of the same tick handler running. Every registration should
  be idempotent, or gated on a `globalThis.__mcp_bridge_registered` flag.

## Filesystem-drop RPC (what the bridge is doing)

The bridge exists because Rhino cannot open network sockets (KubeJS
sandbox). The RPC channel is the filesystem:

```
kubejs/mcp/in/<uuid>.json    Claude writes; bridge reads and deletes
kubejs/mcp/out/<uuid>.json   Bridge writes; Claude reads and deletes
```

Each request file: `{ "id": "<uuid>", "op": "<name>", "args": {...} }`.
Each response file: `{ "id": "<uuid>", "ok": true|false, "result"|"error": ... }`.

Directories are created by the Nix module (`systemd.tmpfiles.rules`),
group-writable so the mcp-minecraft Go server can drop request files
without going through the JVM. The bridge polls `in/` every server tick.

Keep ops **fast and synchronous**. A tick-handler blocking for more than
~40ms will cause "server can't keep up" warnings and lag online players.
For anything expensive, return an ack immediately and stream results
back over multiple ticks.
