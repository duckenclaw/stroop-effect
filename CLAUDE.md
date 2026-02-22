# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Stroop Effect** is a 3D endless runner game built with Godot 4.6. The core mechanic is color-matching: the player must navigate through obstacles by matching their color to the player's current color, creating a Stroop effect-style cognitive challenge.

## Running the Game

```bash
# Run the game
godot --path . src/world.tscn

# Run in headless mode for testing
godot --path . --headless

# Export the project (requires export presets configured)
godot --export-release "Linux/X11" build/game.x86_64
```

## Architecture

### Core Game Loop

The game uses a **signal-driven architecture** with three main controllers:

1. **Player** (`src/player/player.gd`) - Emits signals for game state changes
2. **TerrainController** (`src/controllers/terrain_controller.gd`) - Listens to player signals and manages terrain progression
3. **UI** (`src/ui/ui.gd`) - Listens to both player and terrain controller for HUD updates

### Color System

The game's color system is **material-based**:
- Player and obstacles use `ShaderMaterial` resources stored in `assets/resources/materials/outline-materials/`
- Color matching compares material file paths (e.g., `blue.tres`, `red.tres`)
- Available colors: blue, green, red, yellow, orange, purple (defined by material files)
- Color changes are synchronized across player, obstacles, and collectibles via signals

**Important**: When comparing colors, use:
```gdscript
var obstacle_color = mesh.get_active_material(0).get_path().get_file().get_basename()
```

### Terrain Generation System

Uses an **infinite scrolling belt** pattern:
- `terrain_belt` array maintains 10 visible terrain blocks
- Blocks move toward the player (positive Z direction)
- When front block passes deletion threshold, it's removed and a new block spawns at the back
- Progression through 3 stages based on distance (500m, 1000m, 1500m)
- Stage-specific terrain blocks are stored in `stage_1_blocks`, `stage_2_blocks`, `stage_3_blocks` arrays

### Player Movement

Operates on a **3-lane system**:
- Fixed X positions: `[-2.0, 0.0, 2.0]` (left, center, right)
- Player lerps smoothly between lanes at `MOVE_SPEED = 7.5`
- Z position is locked to 0.0
- Controls: A/D or Arrow Keys for lane switching, Space/W/Up for jump, S/Down for slam

### Collectible System

All collectibles use the **global group pattern**:
```gdscript
# In project.godot
double-jump=""
color-clear=""
color-change=""
color-match=""
flight=""
```

Collectibles are detected via `Area3D.area_entered()` and checked with `area.is_in_group("collectible-type")`.

**Collectible behaviors**:
- `color-change`: Changes player color and increases point modifier
- `color-match`: Changes all obstacles in next 5 terrains to match player color
- `color-clear`: Dissolves all matching obstacles in next 3 terrains
- `double-jump`: Enables double jump for 5 seconds
- `flight`: Enables flight/levitation for 10 seconds

### Obstacle Dissolve Effect

Uses a custom shader at `assets/resources/materials/dissolve_material.tres`:
- Triggered by `start_dissolve(collision_point: Vector3)`
- Animates `sphere_radius` shader parameter from 0.001 to 10.0
- Dissolve center is set to collision point for radial effect
- Frees obstacle node when animation completes

### Point System

**Multiplier mechanics**:
- Base multiplier starts at 1.0
- Color-change collectibles increase multiplier by `modifier_multipier` (max 5.0)
- Multiplier decays to 1.0 after `STREAK_DECAY = 1.5` seconds of no points
- Points awarded: 1.0 for passing obstacles, 2.0 for slam destroys, 1.0 for collectibles

## File Structure Conventions

### Scene Organization
- `src/terrain/terrains/stage1/` - Easy difficulty terrain blocks
- `src/terrain/terrains/stage2/` - Medium difficulty terrain blocks
- `src/terrain/terrains/stage3/` - Hard difficulty terrain blocks
- `src/terrain/terrains/special/` - Special terrain types (free, color_change, stage_change)
- `src/terrain/obstacle-scenes/` - Reusable obstacle prefabs (low, high, wide, moving, etc.)

### Naming Patterns
- Terrain blocks: `terrain_N.tscn` where N is 0-20
- Obstacle scenes: `{descriptor}_obstacle.tscn` (e.g., `low_obstacle`, `hmoving_obstacle`)
- Materials: `{color}.tres` in respective material folders
- Collectibles: `{type}.tscn` matching their global group name

## Common Patterns

### Adding a New Collectible Type

1. Define global group in `project.godot`:
   ```ini
   [global_group]
   new-collectible=""
   ```

2. Create collectible scene inheriting from `src/terrain/collectible/collectible.tscn`

3. Add group to collectible's Area3D node

4. Handle in `player.gd`'s `_on_hitbox_area_entered()`:
   ```gdscript
   elif area.is_in_group("new-collectible"):
       # Handle collectible logic
       area.queue_free()
   ```

5. If timed, add signals and timer logic similar to `double-jump` or `flight`

### Creating New Terrain Blocks

1. Instantiate `src/terrain/terrains/terrain_colliders.tscn` as base
2. Add obstacle instances from `src/terrain/obstacle-scenes/`
3. Ensure obstacles have "obstacle" group and proper Mesh/Collider structure
4. Save in appropriate stage folder
5. Add to corresponding `stage_N_blocks` array in TerrainController scene

### Working with Shaders

All visual effects use custom shaders:
- **Outline shader** (`assets/resources/outline.gdshader`): Used for player and obstacles
- **Dissolve shader** (`assets/resources/dissolve.gdshader`): Used for obstacle destruction
- **World shader** (`assets/resources/world.gdshader`): Used for terrain rendering

Shader parameters can be modified at runtime via `material.set("shader_parameter/param_name", value)`.

## Input Actions

Defined in `project.godot`:
- `jump`: Space, W, Up Arrow
- `left`: A, Left Arrow
- `right`: D, Right Arrow
- `slam`: S, Down Arrow
- `tutorial`: T
- `ui_cancel`: ESC (for pause menu)

## Physics Settings

Custom gravity: `12.0` (higher than Godot's default 9.8 for faster gameplay)

## Debugging Notes

- Player physics is disabled until game start (`set_physics_process(false)` in `_ready()`)
- TerrainController progression starts only after `player.start_game` signal
- Use `push_warning()` for non-critical issues (see material loading in TerrainController)
- Slam detection uses a RayCast3D node on the player
