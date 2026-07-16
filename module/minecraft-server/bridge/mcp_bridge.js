// mcp_bridge.js — filesystem-drop RPC between the Claude MCP server and the
// live Create+ world, via KubeJS server_scripts + Rhino Java interop.
//
// Protocol (see ../CLAUDE.md for context):
//   kubejs/mcp/in/<uuid>.json   client writes; bridge consumes and deletes
//   kubejs/mcp/out/<uuid>.json  bridge writes; client consumes and deletes
//
// Request:  { "id": "<uuid>", "op": "<name>", "args": { ... } }
// Response: { "id": "<uuid>", "ok": true, "result": { ... } }
//        or { "id": "<uuid>", "ok": false, "error": "<message>" }

// Reload guard: /kubejs reload server_scripts re-runs this file, but any
// tick handler registered by the previous run keeps firing until a full
// server restart. Only register once per JVM lifetime.
if (globalThis.__mcp_bridge_registered) {
  console.log("mcp_bridge: already registered, script noop")
} else {
  globalThis.__mcp_bridge_registered = true

  const Files = Java.type("java.nio.file.Files")
  const Paths = Java.type("java.nio.file.Paths")
  const StandardOpenOption = Java.type("java.nio.file.StandardOpenOption")
  const StandardCharsets = Java.type("java.nio.charset.StandardCharsets")
  const BlockPos = Java.type("net.minecraft.core.BlockPos")
  const ResourceLocation = Java.type("net.minecraft.resources.ResourceLocation")
  const ResourceKey = Java.type("net.minecraft.resources.ResourceKey")
  const Registries = Java.type("net.minecraft.core.registries.Registries")
  const BuiltInRegistries = Java.type("net.minecraft.core.registries.BuiltInRegistries")
  const KineticBE = Java.type("com.simibubi.create.content.kinetics.base.KineticBlockEntity")

  const IN_DIR = Paths.get("kubejs/mcp/in")
  const OUT_DIR = Paths.get("kubejs/mcp/out")

  // Poll every 4 ticks (5x/sec). Interactive-latency; keeps the tick
  // handler cheap when the in/ directory is empty (the common case).
  const POLL_PERIOD_TICKS = 4

  const OPS = {
    ping: function (server, args) {
      return { pong: true, tick: server.getTickCount() }
    },

    run_command: function (server, args) {
      if (typeof args.command !== "string") throw new Error("args.command must be a string")
      const exit = server.runCommandSilent(args.command)
      return { command: args.command, exit: exit }
    },

    list_players: function (server, args) {
      const out = []
      const iter = server.getPlayerList().getPlayers().iterator()
      while (iter.hasNext()) {
        const p = iter.next()
        out.push({
          name: p.getName().getString(),
          uuid: p.getUUID().toString(),
          dimension: p.level().dimension().location().toString(),
          pos: [p.getX(), p.getY(), p.getZ()],
          health: p.getHealth(),
        })
      }
      return { players: out }
    },

    get_block: function (server, args) {
      const level = resolveLevel(server, args.dimension)
      const pos = new BlockPos(args.x | 0, args.y | 0, args.z | 0)
      const state = level.getBlockState(pos)
      return {
        block: BuiltInRegistries.BLOCK.getKey(state.getBlock()).toString(),
        properties: stateProperties(state),
      }
    },

    get_kinetic: function (server, args) {
      const level = resolveLevel(server, args.dimension)
      const pos = new BlockPos(args.x | 0, args.y | 0, args.z | 0)
      const be = level.getBlockEntity(pos)
      if (be == null) return { kinetic: false, reason: "no block entity" }
      if (!(be instanceof KineticBE)) return { kinetic: false, reason: "not kinetic" }
      const network = be.getOrCreateNetwork()
      return {
        kinetic: true,
        speed: be.getSpeed(),
        theoreticalSpeed: be.getTheoreticalSpeed(),
        stressImpact: be.calculateStressApplied(),
        network: network != null ? {
          currentStress: network.getCurrentStress(),
          capacity: network.getCapacity(),
          memberCount: network.getSize(),
        } : null,
      }
    },
  }

  function resolveLevel(server, dim) {
    if (dim == null || dim === "overworld" || dim === "minecraft:overworld") {
      return server.overworld()
    }
    const loc = ResourceLocation.parse(dim.indexOf(":") >= 0 ? dim : "minecraft:" + dim)
    const key = ResourceKey.create(Registries.DIMENSION, loc)
    const level = server.getLevel(key)
    if (level == null) throw new Error("unknown dimension: " + dim)
    return level
  }

  function stateProperties(state) {
    const out = {}
    const iter = state.getProperties().iterator()
    while (iter.hasNext()) {
      const prop = iter.next()
      out[prop.getName()] = String(state.getValue(prop))
    }
    return out
  }

  function writeResponse(id, body) {
    const path = OUT_DIR.resolve(id + ".json")
    const tmp = OUT_DIR.resolve(id + ".json.tmp")
    const bytes = JSON.stringify(body).getBytes(StandardCharsets.UTF_8)
    Files.write(tmp, bytes,
      StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING, StandardOpenOption.WRITE)
    // Atomic rename: client sees the file only when fully written.
    Files.move(tmp, path, Java.type("java.nio.file.StandardCopyOption").ATOMIC_MOVE)
  }

  function readRequest(path) {
    const bytes = Files.readAllBytes(path)
    return JSON.parse(new java.lang.String(bytes, StandardCharsets.UTF_8))
  }

  function handleOne(server, path) {
    let id = null
    try {
      const req = readRequest(path)
      id = req.id
      if (!id) throw new Error("missing id")
      const op = OPS[req.op]
      if (!op) throw new Error("unknown op: " + req.op)
      const result = op(server, req.args || {})
      writeResponse(id, { id: id, ok: true, result: result })
    } catch (e) {
      const msg = e && e.message ? e.message : String(e)
      if (id != null) {
        try { writeResponse(id, { id: id, ok: false, error: msg }) } catch (_) {}
      }
      console.error("mcp_bridge: " + (id || "?") + " failed: " + msg)
      if (e && e.javaException) e.javaException.printStackTrace()
    } finally {
      try { Files.deleteIfExists(path) } catch (_) {}
    }
  }

  ServerEvents.tick(function (event) {
    const server = event.server
    if ((server.getTickCount() % POLL_PERIOD_TICKS) !== 0) return
    if (!Files.isDirectory(IN_DIR)) return

    const stream = Files.list(IN_DIR)
    try {
      const iter = stream.iterator()
      while (iter.hasNext()) {
        const path = iter.next()
        if (!path.getFileName().toString().endsWith(".json")) continue
        handleOne(server, path)
      }
    } finally {
      stream.close()
    }
  })

  ServerEvents.loaded(function (event) {
    console.log("mcp_bridge: registered; polling " + IN_DIR + " every " + POLL_PERIOD_TICKS + " ticks")
  })
}
