# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Running the Project

Open the `zanmu-samurai/` folder as a Godot 4.6 project in the Godot editor, then press F5 or use **Project → Run**. There is no CLI build step or test suite — verification is done by running the game.

## Architecture Overview

This is a 3D roguelike. The main scene is `scenes/World.tscn` → `scripts/core/World.gd`, which owns the camera, lighting, HUD, and manages room transitions by instantiating rooms as children. All persistent state lives in the `GameState` autoload singleton.

### GameState (`scripts/core/GameState.gd`)
The single source of truth. The entire floor layout is pre-generated once in `_init_floor()` → `_generate_floor()` using a random-walk algorithm. It produces:
- `room_data: Dictionary` — maps `Vector2i → {type: RoomType, doors: Dictionary, cleared: bool}` for every room on the floor
- `visited_rooms: Dictionary` — maps `Vector2i → RoomType` for minimap fog-of-war (only rooms the player has entered)
- `current_room_pos`, `entry_direction`, `player_health`, `floor_number`, `debug_mode`

Room types: `WELCOME (0), SMALL, MEDIUM, LARGE, OBSTACLE, AMBUSH, EXIT (6)`. First room is always WELCOME, last is always EXIT.

### World (`scripts/core/World.gd`)
Persistent root that owns Camera3D, HUD, WorldEnvironment, and directional lights. On transition, it instantiates the next room at an offset (`ROOM_STEP` dictionary), pans the camera via `tween_method`, then frees the old room and snaps the new room back to origin. The camera sits at `CAM_OFFSET = Vector3(13, 9, 13)` from the room origin (corner isometric view).

### Room (`scripts/room/Room.gd`)
Reads `GameState` on `_ready()` and procedurally builds: floor, walls, doors, enemies. Emits `transition_requested(dir)` when the player steps into a door trigger — World listens and performs the pan. If `skip_player = true`, the room builds without spawning a player (used during the camera pan so the destination room is visible but unoccupied). After the pan, World calls `room.spawn_player()`.

**Critical spawn constraint:** Player must spawn ≥1.8 units from each wall. Door triggers sit 0.36 units inside walls. Spawning closer causes `body_entered` to fire immediately on `_ready()`, triggering an immediate transition.

Door blockers (visual + physics) are stored in `_door_blockers` and freed when `room_cleared` emits. Only after clearing does `_on_room_cleared()` place Area3D triggers in door openings, set `room_data[pos].cleared = true`, and allow navigation.

### Player (`scripts/player/Player.gd`)
`CharacterBody3D`, `MOTION_MODE_FLOATING`, `velocity.y = 0` forced each frame. Collision layer=2, mask=5 (walls + enemies). During dash: layer=0, mask=1 (passes through enemies, hits only walls). `GameState.player_health` is written on every health change so it persists across rooms.

### Enemies (`scripts/enemies/`)
`Kenjutsu.gd` extends `CharacterBody3D` directly (no base class). State machine: `IDLE, CHASE, TELEGRAPH, ATTACK, COOLDOWN`. Uses `MOTION_MODE_FLOATING` + `velocity.y = 0`. Color changes via `ShaderMaterial.set_shader_parameter("albedo", color)` — not `albedo_color`.

### HUD (`scripts/ui/HUD.gd`)
Built entirely in code (no .tscn), owned by World (not Room). Contains `MinimapDraw` as an inner class extending `Control` that overrides `_draw()`. It iterates `GameState.room_data` (all rooms) and skips unvisited rooms unless `GameState.debug_mode` is on. Debug mode also enables one-hit kills and disables damage taken.

### Collision Layers
| Layer | Value | Used by |
|-------|-------|---------|
| 1 | Walls | StaticBody2D walls, door blockers |
| 2 | Player | Player CharacterBody2D |
| 4 | Enemies | Enemy CharacterBody2D |

Player mask = 5 (layers 1+4). Enemy mask = 3 (layers 1+2).

## File Layout

```
scripts/
  core/      GameState.gd, World.gd   ← World.gd is the persistent root
  enemies/   Kenjutsu.gd
  player/    Player.gd
  room/      Room.gd
  ui/        HUD.gd, FloorClearScreen.gd, GameOverScreen.gd
shaders/     toon.gdshader, outline.gdshader

scenes/
  enemies/   Kenjutsu.tscn
  Player.tscn
  Room.tscn
  World.tscn                      ← main scene
```

## Key Gotchas

- **`body_entered` fires on spawn** — if a CharacterBody3D spawns inside an Area3D, the signal fires on the same frame as `_ready()`. Always verify spawn positions have clearance from trigger zones.
- **Pre-generated floor** — never generate rooms lazily; always read from `GameState.room_data`. The EXIT room is placed exactly once during `_generate_floor()`.
- **GDScript typed arrays** — use `Array[String]` not `var dirs := [...]` when the type needs to be inferred later; untyped array literals cause `Cannot infer type` errors.
- **`MOTION_MODE_FLOATING`** — all CharacterBody3D actors use this mode plus `velocity.y = 0` each frame. Never add floor collision to the room; it causes `move_and_slide` conflicts.
- **ShaderMaterial color** — toon-shaded materials use `set_shader_parameter("albedo", color)`, not `material.albedo_color`.
- **macOS Game Embed Mode** — if keyboard input doesn't reach the game, disable "Game Embed Mode" in Editor Settings so the game runs in a separate OS window.
- **Transition guard** — `World._transitioning` prevents re-entrance if the player stands in a doorway while a pan is already running.
