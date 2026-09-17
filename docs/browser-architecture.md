# Browser architecture and blueprint adaptation

## Runtime boundary

Godot 4.6 GDScript, Compatibility renderer, standard single-thread WebAssembly export. Gameplay has no network dependency. Public deployment can use a static HTTP(S) host. Official constraints: <https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html>.

## Implemented data and algorithms

- `GemChunk`: 32×32 cells in one `PackedByteArray`; exactly 8,192 bytes of tile payload per chunk. Offsets 0–1 foreground, 2–3 wall, 4 durability, 5 liquid, 6 reserved lighting, 7 flags. The current block registry uses only the low bytes of the two ID fields. RLE stores a little-endian 16-bit count followed by all eight original bytes, and validates lengths before committing a decoded chunk.
- `GemWorld`: 256×192 tiles / 48 chunks / 393,216 bytes of tile payload per visited planet. At most six planets, roughly 2.25 MiB tile payload plus engine, scripts, queues, metadata and rendering memory. Chunk generation takes one chunk per frame. Global-coordinate noise plus a 3×3 majority sample provides matching chunk boundaries. This is a single smoothing pass, not a general iterative biome automaton.
- `GemMotion`: tile-unit positions; positive Y points down in Godot. Gravity 38 tiles/s²; terminal fall speed 24; run speed 9; jump impulse −13. Collision checks all cells under a substep AABB; travel is divided into ≤0.24-tile increments, resolving Y before X. Coyote time, jump buffering, early-release jump cutoff and half-tile stepping are included. No tile has a physics node. Full slopes are not implemented.
- Mining: first-hit ray march bounded to five tiles; hardness gate, durability decrement, three-second damage expiry, fixed 64-slot drop pool. A full drop pool prevents destruction rather than losing items. Placement checks reach, line of sight, occupancy, fluid presence, player overlap and structural adjacency.
- Rendering: one CanvasItem draws only viewport tiles and a small margin, with code-generated tile motifs. No individual tile sprites or PointLight2D nodes. Local integer BFS uses values 0–15 and stronger attenuation through solids. Player line-of-sight rays reveal bit 7 in the flags byte. Explored terrain retains a dim minimum brightness. Lighting is currently flat tile modulation, not dual-channel smooth interpolation.
- Simulation: fixed physics ticks; nine neighboring chunks share the water scheduler. Each transfer checks destination capacity and type and subtracts exactly the amount added. Twenty pooled slime bodies have jump/chase behavior and contact damage. Simulation runs only around the active player. Distant drops remain bounded by the fixed pool.
- Crafting: ingredient validation precedes mutation. Advanced recipes query a nearby workbench. Copper tools unlock clay/iron/crystals; crystal tools unlock obsidian. Generators traverse connected wire/drill cells on a bounded two-second tick; drills mine the cell immediately below. Conveyors move drops to the right. These are intentionally small automation building blocks, not full cached circuit or pipe solvers.
- Saving: two alternating checkpoint slots. One chunk RLE file is written each rendered frame; metadata is committed last. The game is paused until completion, keeping inventory and terrain consistent. Outstanding item drops are collected before a checkpoint. The previous slot remains available if writing the new checkpoint fails. Load validates metadata, inventory bounds, planet membership and each chunk; a damaged newest checkpoint falls back to the previous complete one. The next save preserves the recovered slot. Enemy state and transient projectiles are not saved.

## Corrections to the pasted blueprint

1. C# cannot be the Godot 4 browser gameplay language with the standard export pipeline. GDScript is used throughout; no C# files or .NET project feature remain.
2. A fixed 3×4 collision neighborhood cannot cover arbitrary high-speed displacement. Substeps bound movement and query the actual AABB cells instead.
3. Godot Y increases downward; the original negative gravity / Y−1 fluid examples must be inverted.
4. A 0–15 light channel cannot meaningfully use attenuation 32 in air. Local light uses loss 1 in air and 5 in solids. Field 6 remains available for a future pair of nibbles.
5. The source allocates all eight automation bits and also assigns one to exploration. This prototype reserves bit 7 solely for exploration; a future full circuit system needs a separate explored bitset or separate sparse circuit metadata.
6. Fluid transfers preserve volume and capacity; they do not blindly empty into partially filled cells.
7. Fixed pools, bounded loops and compact arrays reduce cost but GDScript/UI execution is not a zero-allocation runtime. The project does not claim zero allocations or universal 60 FPS.

## Remaining blueprint systems

| Area | Remaining work |
| --- | --- |
| Terrain | Desert region, biome-specific hazards, richer structures, streaming of larger planets |
| Movement | True slopes/half-block geometry, hard rope constraint, specialized gear |
| Lighting | Separate sky/emission channels, light-removal updates, bilinear GPU texture, ambient effects |
| Building | Multi-tile ownership, containers, housing flood fill, NPCs, boss relic progression |
| Combat | Bosses, cavelings, spatial buckets, ranged projectiles, armor and damage types |
| Fluids | Pipes, pressure networks, intake pumps, sprinklers, acid/oil interactions |
| Automation | Separate red/blue circuits, logic gates, delays, grabbers, directional conveyors |
| Persistence | Background coherent snapshots, save migration and portable save download |
| Multiplayer | Authoritative service, WSS transport, protocol versioning, rate limits, interest management and reconciliation |
| AI | Server-side authenticated relay, request budgets, validated responses, timeout/fallback behavior |

Multiplayer cannot be provided by a static browser export acting as a listening server. The eventual browser client must use WSS or WebRTC and connect to a separately hosted authoritative service. No such service or client implementation is included here. AI similarly needs a server-owned credential and a verified, currently available API model; the pasted document's model name and sampling restrictions are not treated as a verified API contract. No secrets belong in exported assets.
