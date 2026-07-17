# CLAUDE.md — mcp-kubejs authoring notes

TypeScript here compiles (esbuild, `--target=es2015`) to a single IIFE
bundle executed by **KubeJS's Rhino fork** (2101.x for MC 1.21.1) inside
the Minecraft server JVM. Rhino is not V8. Read this before editing.

## Language constraints

esbuild lowers syntax to ES2015 (`?.`, `??`, etc. are fine in source),
but it does **not** polyfill runtime features, and Rhino has no event loop:

- **No `async`/`await`/`Promise`, enforced at compile time.**
  `dev.latvian.mods.rhino` (KubeJS's Rhino fork, checked directly in the
  jar) ships no `NativePromise` class and no JS-level polyfill —
  `Promise` is an undefined global at runtime. esbuild's downlevel
  transform for `async`/`await` still calls `new Promise(...)` under the
  hood (it's a generator + `__async` helper, not a from-scratch
  synchronous rewrite), so unguarded async code would build cleanly and
  throw `ReferenceError` the instant it first ran. `tsconfig.json`
  deliberately omits `ES2015.Promise` from `lib` (while including the
  rest of `ES2015.*` individually) so `Promise` only exists as an ambient
  *type*, not a runtime value: `tsc --noEmit` now hard-errors on any
  `async function`/method/arrow (TS2705/TS2468) and on `new Promise(...)`
  / `Promise.resolve(...)` (TS2585) — the existing `tsc --noEmit` step in
  `default.nix`'s buildPhase catches these before esbuild ever runs.
  Type-only uses of `Promise<T>` (e.g. a signature nothing ever actually
  constructs) still slip through, so this isn't airtight, but it catches
  the code that would actually crash.
- **No `setTimeout`/`setInterval`** — no timers. Delayed work goes through
  game ticks (`ServerEvents.tick`) or `server.scheduleInTicks`.
- **No npm packages** — assume nothing beyond ES2015 builtins exists at
  runtime. Pure-JS, dependency-free code can be bundled in; anything
  touching node/browser APIs cannot.
- Keep source conservative: prefer plain functions over classes,
  no generators, no call-spread on Java methods.

## Java interop

`Java.loadClass("fully.qualified.Name")` is the KubeJS 7 API (throws if
the class filter denies; `Java.tryLoadClass` returns null instead).

The class filter: exact-deny → exact-allow → prefix-deny → **default
allow**. Denied: `java.net`, `java.nio`, `java.io`, most of `java.lang`
(String/boxed/Runnable allowed — no Thread), `io.netty`, reflection.
Everything else — `net.minecraft.*`, `com.simibubi.create.*`,
`dev.latvian.apps.tinyserver.*` — is reachable.

Gotchas:

- **Java collections auto-wrap:** `List` acts like a JS array, `Map` like
  an object, `for..of` works on `Iterable` — but `Array.isArray(javaList)`
  is `false`.
- **Null vs undefined:** Java `null` arrives as JS `null`; use `x == null`
  to cover both.
- **Java exceptions are catchable:** `catch (e) { ... }`; the underlying
  throwable is `e.javaException`.
- **Overload resolution is heuristic.** On "no matching signature", pass
  explicitly-typed args: `Java.to(arr, "java.lang.Object[]")`.
- **SAM conversion:** JS arrow functions convert to single-abstract-method
  interfaces (`Runnable`, `Supplier`, tinyserver's `HTTPHandler`).

## Threading

tinyserver handlers run on their own thread; **all world access must
happen on the game thread**. `src/mcp.ts` handles this: set
`onGameThread: true` on a tool and its `run` is wrapped in
`Utils.server.executeBlocking(...)` (MinecraftServer extends
BlockableEventLoop; runs inline if already on the game thread).

Keep game-thread work **under ~40ms** — it blocks a server tick and lags
online players. For expensive operations, return an ack and do the work
across ticks.

## Reload lifecycle

`/kubejs reload server_scripts` re-runs the bundle in a fresh scope, but
JVM-side objects created by the old run (the bound HTTP server, any
registered event handlers) survive. `src/main.ts` handles the HTTP server
by stashing its handle in KubeJS `global` and stopping the stale instance
before rebinding. If you ever register `ServerEvents.*` handlers, make
registration idempotent the same way, or you'll accumulate N copies per
reload until a full restart.

## Logging

`console.info/warn/error` is the KubeJS logger — output lands in
`logs/kubejs/server.log` on the server, **not** `latest.log`.

## Reaching Create internals

Create's kinetic base is
`com.simibubi.create.content.kinetics.base.KineticBlockEntity`:

- `.getSpeed()` — signed RPM at this shaft (negative = reverse)
- `.getTheoreticalSpeed()` — target RPM ignoring overstress
- `.calculateStressApplied()` — this block's SU draw
- `.getOrCreateNetwork()` — shared `KineticNetwork`, with
  `.getCurrentStress()` and `.getCapacity()`

```ts
const KineticBE = Java.loadClass(
  "com.simibubi.create.content.kinetics.base.KineticBlockEntity",
);
const be = level.getBlockEntity(pos);
if (be instanceof KineticBE) {
  const network = be.getOrCreateNetwork();
  const stress = network != null ? network.getCurrentStress() : 0;
}
```

**Fragility warning:** these are private-ish Create implementation
methods. Renames won't fail at build time (typed as `any`); you get a
runtime error the first time the call runs. Test after every Create
version bump.

## Script contexts (where the bundle loads)

| Folder | When it runs | Notes |
|---|---|---|
| `startup_scripts/` | Once at JVM startup | Registry work; no world yet. |
| `server_scripts/` | Every world load; hot-reloadable | **The bundle lives here.** |
| `client_scripts/` | Client only | N/A — dedicated server. |
