# Gem Finder
![Godot Version](https://img.shields.io/badge/Godot-4.6-blue) ![Status](https://img.shields.io/badge/Status-Prototype-green) ![License](https://img.shields.io/badge/License-MIT-orange)

<h3>Link to game ready to play in browser:</h3>
<br>https://sebslo.itch.io/gem-finder-finder
<br>

It's a repository ready to open in godot 4.6 as project.


<img width="25%" alt="4" src="https://github.com/user-attachments/assets/f726dc19-8259-40e3-ab6b-807f829ab4d2" />
<img width="24%" alt="3" src="https://github.com/user-attachments/assets/c35bfe4e-246a-4e26-be56-85264e94da94" />
<img width="24%" alt="2" src="https://github.com/user-attachments/assets/fd1ee5b0-e1d4-4b4a-9e69-5c99866ec246" />
<img width="24%"  alt="1" src="https://github.com/user-attachments/assets/731e0ea4-c175-49d7-9a84-27da851d71c7" />


Gem Finder is a browser-playable 2D sandbox adventure built with Godot 4.6 and GDScript. Land on an alien planet, mine into procedural caves, collect resources, craft upgrades, automate extraction, awaken the Core, and prepare a spacecraft for the next world. The project draws inspiration from the exploration, progression, and automation loops of games like *Terraria* and *Core Keeper*, featuring its own custom art direction and systems.

## Features

**Core Gameplay**
- Procedural, seeded planets with persistent terrain changes.
- Varied biomes including forest-surface landing zones, underground caverns, caves, ore veins, and water.
- Mining, block placement, item drops, crafting, tool tiers, and progression gates.
- Action mechanics: grappling hook, combat, slimes, health/energy management, and exploration fog.
- Automation systems: conveyors, generators, wires, and automatic drills.

**Technology & Interface**
- Browser build utilizing WebAssembly and WebGL 2.
- Local browser saves with checkpoint recovery.
- Custom tile collision and responsive platform movement.
- Compact pixel-art HUD, hotbar, pause menu, settings, character selection, and star chart.

## Controls

| Key / Input | Action |
| :--- | :--- |
| **A / D** or **Left / Right** | Move |
| **Space / W / Up** | Jump or swim |
| **Left Mouse** | Mine, attack, or use selected tool |
| **Right Mouse** | Place selected building item |
| **1–9 / Mouse Wheel** | Select hotbar item |
| **Q** | Grapple / Release grapple |
| **C** | Open Crafting |
| **E** | Interact with the Core |
| **M** | Star chart |
| **Enter** | Open chat |
| **Escape** | Pause or return |

## Multiplayer & Admin Commands

The multiplayer interface is built as a foundation for WebSocket-based shared worlds. Server operators can authenticate as admins and utilize the following commands:

```text
/help
/players
/items
/spawn <item> [amount] [player]
/god [on|off] [player]
/fly [on|off] [player]
```
Development Status
Gem Finder is an in-development prototype. While the single-player sandbox loop is fully playable, a production multiplayer release still requires a deployed authoritative WebSocket server, server-side world validation, account/session handling, moderation tools, rate limits, and secure WSS hosting.

AI Assistance
This project was developed with assistance from GPT-6 Astra. The AI acted as a development collaborator for planning, code iteration, debugging, documentation, and prototype implementation. The creator remains responsible for reviewing, testing, and shipping the project.

License
This project is licensed under the MIT License. See the LICENSE file for details.
/tp <x> <y> [player]
/tp <player> [player]
