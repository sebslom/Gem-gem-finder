# Gem Finder

A playable Godot 4.6 **GDScript** sandbox prototype that exports to a browser using WebAssembly and WebGL 2. It uses the standard Godot editor, Compatibility rendering, and the **nothreads** web template. No .NET runtime, extensions, external assets, API keys, or cross-origin isolation headers are required.

## Play

The exported game is in `build/web/index.html`. Serve the **whole folder** over HTTP; opening the HTML as a local file will not work.

```powershell
python -m http.server 8066 --bind 127.0.0.1 --directory build/web
```

Open <http://127.0.0.1:8066>. The current UI targets desktop browsers with a keyboard and mouse. Touch controls, gamepad support and mobile layout are not implemented.

| Input | Action |
| --- | --- |
| A/D or left/right | Move |
| Space, W or up | Jump; release early for a shorter jump; swim |
| 1–9 or mouse wheel | Select tool or building item |
| Left mouse | Mine, attack with blade, or place selected item |
| Right mouse | Place selected building item; earth when a tool is selected |
| Q | Grapple to the aimed solid block; press again to release |
| C | Crafting menu; advanced recipes require a nearby workbench |
| E | Offer five crystals to the Core while nearby |
| M | Star chart; travel after crafting a spacecraft |
| Escape | Pause / resume |

Mine the copper deposits in the landing chamber floor. Collect earth and stone, craft and place a workbench, then craft a copper pickaxe. Descend through the clay barrier for iron and crystals. A crystal pickaxe opens the obsidian boundary. Craft a spacecraft to visit six deterministic planets; terrain changes remain when revisiting them. Slimes also drop crystals. Save from the pause menu; an automatic checkpoint runs after 90 seconds of active play.

## Rebuild

Use **standard Godot 4.6**, not the .NET editor. Godot's .NET editor refuses Web exports even when the project contains only GDScript.

The helper retrieves the official release archive using HTTP ranges and downloads only the required web templates. `--engine` also retrieves the matching standard Windows editor. ZIP CRCs are verified during extraction.

```powershell
python tools/fetch_web_template.py
python tools/fetch_web_template.py --engine
.\tools\templates\Godot_v4.6-stable_win64_console.exe --headless --path . --export-release Web build/web/index.html
```

The Web preset references `tools/templates/web_nothreads_debug.zip` and `web_nothreads_release.zip`. The similarly named `web_release.zip` is threaded and must not be substituted. Downloaded binaries and exports are ignored by Git.

Upload the contents of `build/web` together to an HTTPS static host. Serve `.wasm` as `application/wasm`; enable gzip or Brotli on the host to reduce the initial download. This project has not been published to an external host.

## Verification

```powershell
.\tools\templates\Godot_v4.6-stable_win64_console.exe --headless --path . --script res://tests/run.gd
```

The current suite passes **93 checks**. Tests exercise full-field RLE round trips, malformed streams, repeatable generation, safe spawn and swept collision, cross-chunk fluid conservation, mining and pickup, pool exhaustion, invalid placements, crafting progression, combat line of sight and invulnerability, connected drills, conveyors, planet persistence, ten seconds of integrated simulation, and save restoration with corrupted-checkpoint recovery. Fixtures are written only to `tests/save-fixture`, excluded from export.

## Scope

This is a browser-playable foundation, **not a complete implementation of the ten-part master blueprint**. Implemented: three depth regions, six seeded planets, chunk arrays, custom collision, mining, placement, crafting, grapple, slime combat, pooled drops, local lighting and exploration, water flow, conveyors, connected generator/wire/drill chains, a Core interaction, and browser saves.

Not implemented: multiplayer/server reconciliation, generative AI integration, bosses, NPC housing, containers, multi-tile furniture, fluid pipes/pumps, acid/oil reactions, logic gates, smooth shader lighting, the desert biome, or free-flight space navigation. The star chart performs planet travel. See `docs/browser-architecture.md` for the decisions and remaining work.

Save data uses Godot's `user://` filesystem (IndexedDB on the Web), scoped to the browser profile and site origin. Browser privacy settings or cleared site storage can prevent persistence. Saves pause the simulation for one serialized chunk per frame; this deliberately favors consistent checkpoints over the blueprint's uninterrupted-save requirement. Rendering performance depends on hardware and viewport; locked 60 FPS is not promised.
