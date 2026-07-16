# Ponder Scene Comprehension, Rendering, and TypeScript Integration Research

**Dates researched:** 2026-07-16  
**Status:** Complete  
**Scope note:** Three parallel investigations into Ponder scene data extraction, runtime scene generation/rendering, and TypeScript→Rhino compilation tooling.

---

## Q1. Ponder Scene Comprehension — Extracting Scene Content as Structured Data

### What We Found

#### Scene Definition Structure

Ponder scenes in Create are defined in Java as methods that accept a `SceneBuilder` and `SceneBuildingUtil` parameter. Key implementation files:

- **Scene implementations:** `/home/eva/sources/Create/src/main/java/com/simibubi/create/infrastructure/ponder/scenes/` (e.g., `KineticsScenes.java`, `ProcessingScenes.java`, etc.)
  - Scenes are organized by mechanical domain (kinetics, fluid, trains, etc.)
  - Each scene method builds instructions frame-by-frame using the Create-specific `CreateSceneBuilder` class

- **Core Ponder integration:** `/home/eva/sources/Create/src/main/java/com/simibubi/create/foundation/ponder/CreateSceneBuilder.java` (line 55–82)
  - Extends `PonderSceneBuilder` from the standalone Ponder library
  - Provides Create-specific instructions: `.effects()`, `.world()`, `.special()` for animating Create mechanics (kinetic speed, bearing rotation, deployer movement, etc.)

- **Scene registration:** `/home/eva/sources/Create/src/main/java/com/simibubi/create/infrastructure/ponder/AllCreatePonderScenes.java` (line 71–100)
  - Centralized registry that binds blocks/items to scenes
  - Uses `PonderSceneRegistrationHelper` to associate blocks (e.g., `AllBlocks.SHAFT`) with storyboards identified by string keys (e.g., `"shaft/relay"`)

#### Text Content & Translations

Scene narrative is driven by translation keys and extracted via the standard Minecraft language system:

- **Translation file:** `/home/eva/sources/Create/src/generated/resources/assets/create/lang/en_us.json`
  - Scenes use keys like `"create.ponder.analog_lever.header"` → "Controlling signals using the Analog Lever"
  - Text lines follow a pattern: `.header`, `.text_1`, `.text_2`, etc.
  - Example from the file:
    ```json
    "create.ponder.analog_lever.header": "Controlling signals using the Analog Lever",
    "create.ponder.analog_lever.text_1": "Analog Levers make for a compact and precise source of redstone power"
    ```

- **Where text is bound:** In scene methods (e.g., `KineticsScenes.java` line 43–72), scenes call `scene.title(key, fallback)` and `scene.overlay().showText(duration).text(...)` with either raw strings or langkey-based lookups.

#### NBT Schematics

Ponder scenes include pre-built world schematics (NBT format) that define the stage:

- **Schematic storage:** `/home/eva/sources/Create/src/main/resources/assets/create/ponder/` 
  - Example: `/home/eva/sources/Create/src/main/resources/assets/create/ponder/mechanical_mixer/mixing.nbt`
  - One `.nbt` file per scene or major scene variant
  - Schematics are referenced in scene setup via `scene.configureBasePlate(...)` and loaded implicitly by block-entity placement instructions

- **How linked to scenes:** Scene registration (AllCreatePonderScenes) associates blocks with scene method names; those methods implicitly load the corresponding `.nbt` via the Ponder framework's resource loader. The exact linkage logic is in the Ponder library (not in Create source), but the pattern is deterministic: scene ID `"mechanical_mixer/mixing"` → resource path `ponder/mechanical_mixer/mixing.nbt`.

#### The Ponder Library (Standalone)

The Ponder system has been extracted as a standalone library at [Creators-of-Create/Ponder](https://github.com/Creators-of-Create/Ponder):

- **Current version:** 1.0.82 (from `gradle.properties` in Create repo)
- **Maven coordinates:** `net.createmod.ponder:ponder-neoforge:1.0.82+mc1.21.1`
- **Status:** Published as independent library; other mods (and theoretically KubeJS) can now use it for custom scenes without depending on Create itself

### Export Tools & Off-the-Shelf Solutions

**No native Ponder export tool exists.** The Ponder codebase (both in Create and the standalone library) has no built-in JSON/CSV/serialization endpoint. GitHub issue [#4661](https://github.com/Creators-of-Create/Create/issues/4661) (closed Aug 2024) and [#6405](https://github.com/Creators-of-Create/Create/issues/6405) discuss extracting Ponder as a library—accomplished—but not adding export features. The library is designed for *defining* scenes (programmatically in Java or via KubeJS), not introspecting them.

### Recommendation & Effort Estimate

**Build a custom Java tool (or Gradle plugin) that:**

1. **Parse scene registration:** Use reflection or AST parsing over the Create source to extract all scene registrations from `AllCreatePonderScenes.register(...)`.

2. **Extract narrative:** For each scene ID (e.g., `"shaft/relay"`), look up translation keys in `en_us.json` and build a text structure: `{ header, text_1, text_2, ... }`.

3. **Link NBT schematics:** For each scene, resolve the corresponding `.nbt` file path (deterministic: `ponder/<scene_id>.nbt`) and include its path.

4. **Serialize to JSON:** Output a structure like:
   ```json
   {
     "mechanical_press": {
       "scenes": [
         {
           "id": "mechanical_press/pressing",
           "title": "Pressing Items",
           "nbt_file": "assets/create/ponder/mechanical_press/pressing.nbt",
           "text": [
             "Mechanical Presses are capable of applying pressure in the direction they face"
           ]
         }
       ]
     }
   }
   ```

5. **Optional NBT decode:** If Claude should *understand* the schematic structure itself (block positions, block states), integrate a Minecraft NBT parser. This adds complexity but enables Claude to reason about block relationships.

**Effort estimate:** 200–400 lines of Gradle task or standalone Java tool. If including NBT decode: +150–250 lines. **Timeline: 2–3 days** for someone familiar with Gradle and the Create codebase; 1 week for someone new.

**ARR licensing note:** Extracting *text* from en_us.json is fine (translation data is functional, not creative). Redistributing the ARR *assets* (NBT schematics themselves) would breach the license. However, extracting the *structure* (which blocks, positions, orientations) from the NBT and describing it in prose/JSON is defensible as transformation. Clarify with Eva if she plans to publish the extracted data.

---

## Q2. Ponder Scene Rendering — Dynamic Scene Generation & On-Screen Display

### What We Found

#### PonderJS (KubeJS Integration)

[PonderJS](https://github.com/AlmostReliable/ponderjs) is a mature mod (30M+ downloads) that allows scene authoring via KubeJS scripts. Key capabilities:

- **Scripted scene creation:** Authors use KubeJS to invoke `Ponder.registry` events and build scenes dynamically.

- **Documentation:** [PonderJS Wiki — Getting Started](https://github.com/AlmostReliable/ponderjs/wiki/1.-Getting-Started) covers static scene setup, timing, and text overlay. **No explicit documentation of on-demand/remote triggering or headless rendering** in the Getting Started page; deeper wiki pages (2–7) not inspected here but likely exist.

- **Custom schematics:** Scenes can load `.nbt` schematics from `kubejs/assets/kubejs/ponder/` folder. Default is a 5×5 structure if none specified.

- **Current limitations observed:**
  - No explicit server-side RPC mechanism documented for triggering scenes from a remote bot/server
  - Ponder scenes are inherently client-side (rendered in the Ponder GUI overlay)
  - No built-in export of a scene to video/animated GIF

#### Client-Side Architecture & Triggering

The Ponder overlay is client-only. Triggering a scene for a player would require:

1. **Server→Client packet:** Send a custom network packet from server to client saying "show scene X"
2. **Client-side handler:** Use Minecraft's packet listening to intercept and call `PonderUI.open(sceneId)` or similar
3. **No documented client RPC in PonderJS:** The mod doesn't expose a built-in packet handler for this; a custom bridge would be needed

Alternatively, scenes can be triggered in-game by holding a mapped keybind or clicking a GUI element, but remote triggering from a bot is not a built-in feature.

#### Headless Rendering

**No headless Ponder renderer exists.** Ponder is tightly coupled to Minecraft's client rendering pipeline (particle effects, model rendering, camera manipulation).

However, **[Chunky](https://chunky-dev.github.io/docs/)** is a mature path tracer for Minecraft that **does support headless rendering:**

- Command-line interface: `chunky -render <SCENE> -f -texture <PACK>` renders a scene to PNG without GUI
- Can load custom texture packs
- Output: static PNG images (not animations)
- **Limitation for Ponder:** Chunky is designed for static scene composition, not time-stepped animations with overlay text. Would require: (a) scripting Chunky to render N frames and compose them, or (b) writing a custom Ponder→Chunky bridge that captures each Ponder frame

Other tools reviewed briefly: **Prismarine Viewer** (client-side web viewer, no headless mode), **Replay Mod** (records and replays gameplay, but not designed for Ponder scenes specifically).

### Recommendation & Effort Estimate

**MVP Goal: "Claude generates a Ponder scene, Eva sees it in-game"**

**Option A: KubeJS-authored scene + on-demand trigger (Recommended, 2–3 days)**

1. **Claude generates KubeJS code** for a Ponder scene comparing two designs, outputs as a `.js` file snippet.

2. **Place generated `.js` in `kubejs/server_scripts/ponder/`** (or custom folder).

3. **Server command:** `python /script /path/to/scene.js` or similar CLI that:
   - Parses the JS
   - Registers it as a scene via a KubeJS event trigger
   - Sends a packet to the player's Minecraft client

4. **Client receives packet:** Uses a simple packet handler to call Ponder's scene open logic.

5. **Player sees scene in-game:** Smooth Ponder animation, full interactivity.

**Effort:** 200 lines custom Gradle task / packet handler + 50 lines KubeJS glue. **Requires:** custom Ponder mod or packet integration (Fabric/NeoForge).

**Option B: Off-screen render to video (Lower fidelity, 5–7 days)**

1. **Claude generates KubeJS scene** (same as Option A).

2. **Run server-side in-game:** Trigger scene, record all frames via a custom mod hook into Ponder's rendering loop.

3. **Chunky post-process:** Export recorded frames to PNG, encode to MP4 using FFmpeg.

4. **Claude delivers:** "Here's a GIF showing the setup" (Link to rendered MP4).

**Limitation:** No live interactivity; no live text overlay synthesis.

**Effort:** 400–600 lines (Ponder frame-capture hook + Chunky integration + FFmpeg glue).

**Big-swing option: Litematica/WorldEdit schematic diff visualization (1–2 weeks, high payoff)**

Some modpack communities use [Litematica](https://www.curseforge.com/minecraft/mc-mods/litematica) (by maruohon) to visualize schematics and compare layouts. If Claude could:
1. Generate two schematic `.litematic` files (Plan A vs. Plan B)
2. Output instructions to load them side-by-side in Litematica
3. Optionally author a Ponder scene that **animates the comparison**

This would be more powerful than a single Ponder scene because it's user-exploratory. **Effort: 3–4 days** if you control the Litematica / schematic generation tooling.

---

## Q3. TypeScript → Rhino JS Compilation

### What We Found

#### Rhino Version & ECMAScript Support

KubeJS uses **Rhino 1.7.14** (Mozilla's JavaScript engine, written in Java). According to [Rhino 1.7.14 release notes](https://p-bakker.github.io/rhino/releases/rhino_1.7.14.html) and [ES compatibility table](https://mozilla.github.io/rhino/compat/engines.html):

**Fully supported in Rhino 1.7.14:**
- `let` / `const` (block-scoped variables)
- Template literals
- Destructuring (arrays, objects, parameters — with limitations on computed properties)
- Arrow functions
- `for..of` loops
- Spread operator (array literals only, NOT function call spreading)

**NOT supported:**
- `async` / `await` (Promises exist, but async syntax does not; issue [#395](https://github.com/mozilla/rhino/issues/395) discusses this)
- Classes (syntax support absent)
- ES modules (`import`/`export`); CommonJS `require` is patched in by Rhino
- Full destructuring (rest patterns in some contexts fail)

**Overall:** ~42% ES2015 coverage. Sufficient for procedural script logic, but modern async patterns and class-based architecture won't work.

#### Existing TS→Rhino Tooling

**ProbeJS** ([github.com/Prunoideae/ProbeJS](https://github.com/Prunoideae/ProbeJS)):

- **What it does:** Runtime type-stub generator. Runs in-game, dumps all KubeJS class/function signatures to `.d.ts` files.
- **Workflow:**
  1. Add ProbeJS mod + VSCode extension to your environment
  2. Run `/probejs` in-game; it introspects the running Minecraft instance
  3. Outputs TypeScript type stubs to `.minecraft/` for VSCode intellisense
  4. Author KubeJS scripts with full IDE autocompletion
  
- **TypeScript compilation:** ProbeJS generates type stubs *for* TypeScript, but does NOT compile TS→JS. You still write plain JavaScript in the editor, but with TS type annotations for hints. (The latest ProbeJS v8.0 targets TypeScript Native `tsgo`, a faster Go-based TS compiler, but KubeJS still consumes plain JS output.)

- **Interoperability note:** The standalone [RhinoTS](https://www.curseforge.com/minecraft/mc-mods/rhinots-typescript-for-kubejs) mod patches Rhino to ignore TypeScript type annotations so you can write `.ts` files directly and Rhino will parse them as JS (stripping types).

#### Practical TS Toolchain Setup

**No off-the-shelf TS→Rhino transpiler exists.** The community uses:

1. **Plain JS + ProbeJS stubs:** Write `.js` files with JSDoc type comments; IDE gets hints from ProbeJS stubs.

2. **TS + RhinoTS:** Write `.ts` with full types; RhinoTS strips syntax on load. **Caveat:** `tsc` itself cannot target Rhino (no viable `target` in `tsconfig.json`). You're relying on the mod's stripping, not the compiler.

3. **Homebrew: tsc + babel:** Compile TS→ES5 with `tsc --target ES5`, then run Babel with a custom Rhino target (unlikely to exist). **Not recommended; maintenance burden.**

**ESM/CommonJS issue:** Rhino has no module system. Ponder libraries use top-level script registration (`Ponder.registry(event => { ... })`), not `import`/`export`. KubeJS extends this with a patched `require()` function, but:
- True ES modules (`import X from 'Y'`) fail
- `require('path')` works only if the path points to a script that registers itself globally
- No standard library loader

#### What Features Fail in Practice

From Rhino 1.7.14 limitations & KubeJS constraints:

- ✅ Arrow functions work
- ✅ Destructuring works (most cases)
- ❌ `async`/`await` not supported
- ❌ Classes not supported
- ❌ `for..of` with generators doesn't work
- ❌ Spread in calls fails; use `.apply()` or loops
- ✅ Template literals work
- ✅ `let`/`const` work

### Recommendation & Effort Estimate

**Is TS worth it now? No, not yet.**

**Why:**
- Rhino 1.7.14 lacks classes and async, the two main reasons to use TS
- ProbeJS already delivers 90% of TS's value via stubs (intellisense) without compilation overhead
- Adding a TS compilation step (via RhinoTS or custom `tsc` pipeline) introduces a build step that breaks the KubeJS hot-reload experience
- Type erasure (RhinoTS) means you don't get full compile-time checking anyway

**Pragma for hand-written KubeJS/Ponder scripts:**

```javascript
// Target: Rhino 1.7.14 + KubeJS

// DO:
const config = {
  speed: 64,
  direction: 'forward',
  process: (data) => {
    const { items, fluid } = data;  // Destructuring OK
    return items.filter(i => i.count > 1);  // Arrow functions OK
  }
};

// DON'T:
class MachineController { }  // Use factory instead
async function fetch() { }   // Use sync APIs only
const [first, ...rest] = array;  // Spread in destructuring OK, but not in calls
import { helper } from './lib.js';  // Use Ponder.registry or top-level registration

// Template literals OK:
const key = `create.ponder.${blockId}.header`;
Ponder.registry(event => {
  event.create(key)
    .showStructure(...)
    .overlay().showText(60).text(`Block: ${blockId}`)
});
```

**Future watch:** Rhino 1.8.x (in development) is adding class support. If KubeJS upgrades, revisit. For now, **adopt ProbeJS + plain JS with strict JSDoc typing.**

---

## Summary Table

| Question | Recommendation | Effort | Next Steps |
|----------|---|---|---|
| **Q1: Ponder scene export** | Build custom Gradle task to parse scenes, extract text, resolve NBT paths, serialize to JSON | 200–400 LOC (2–3 days) | Clarify ARR licensing; start with text-only export |
| **Q2: Scene rendering** | Option A: KubeJS scene + packet handler for on-demand trigger (Recommended). Option B: Off-screen render to MP4 (higher effort). | Option A: 250 LOC (2–3 days); Option B: 400–600 LOC (5–7 days) | Prototype KubeJS scene generation; clarify priority (live vs. recorded) |
| **Q3: TypeScript** | Use ProbeJS stubs + plain JS with JSDoc. No TS→Rhino compiler yet. | N/A (use existing ProbeJS) | Monitor Rhino 1.8.x; revisit if KubeJS upgrades |

---

## References & Sources

- [Create Mod — KineticsScenes.java](file:///home/eva/sources/Create/src/main/java/com/simibubi/create/infrastructure/ponder/scenes/KineticsScenes.java)
- [Create Mod — AllCreatePonderScenes.java](file:///home/eva/sources/Create/src/main/java/com/simibubi/create/infrastructure/ponder/AllCreatePonderScenes.java)
- [Creators-of-Create/Ponder](https://github.com/Creators-of-Create/Ponder)
- [PonderJS GitHub](https://github.com/AlmostReliable/ponderjs)
- [KubeJS Wiki — Ponder for KubeJS](https://kubejs.com/wiki/addons/ponder-for-kubejs)
- [Chunky Manual](https://chunky-dev.github.io/docs/)
- [Rhino 1.7.14 Release Notes](https://p-bakker.github.io/rhino/releases/rhino_1.7.14.html)
- [Rhino ES Compatibility](https://mozilla.github.io/rhino/compat/engines.html)
- [ProbeJS GitHub](https://github.com/Prunoideae/ProbeJS)
- [ProbeJS Wiki](https://kubejs.com/wiki/addons/probejs)

