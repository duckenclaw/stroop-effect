## Project Overview

**Stroop Effect** is a 3D endless runner game built with Godot 4.6. The core mechanic is color-matching: the player must aboud obstacles, but they can also destory obstacles with a color that matches the player's current color, creating a cognitive/visual challenge based on the Stroop's Effect.

## Running the Game

```bash
godot --path . src/world.tscn
```

```bash
godot --path . --headless
```

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . src/world.tscn
```

## Building

Every target is driven by a preset in `export_presets.cfg`, exported by preset **name**. Building
needs export templates whose version matches the editor exactly (currently `4.6.dev2`) -- install
them from the editor under *Editor -> Manage Export Templates*, or unpack the official `.tpz` into:

- macOS: `~/Library/Application Support/Godot/export_templates/<version>/`
- Linux: `~/.local/share/godot/export_templates/<version>/`
- Windows: `%APPDATA%\Godot\export_templates\<version>\`

Import every asset and parse every script first -- this catches broken resources and script errors
that an export would otherwise bake into the build:

```bash
godot --path . --headless --import
```

### macOS

```bash
godot --path . --headless --export-release "macOS"
```

Writes a universal (x86_64 + arm64) `build/macOS/stroop-effect.dmg`. The preset carries no signing
identity, so the app is **ad-hoc signed**: it runs on the machine that built it, but Gatekeeper
blocks it everywhere else until it is signed with a Developer ID and notarized. Verify a build with:

```bash
hdiutil verify build/macOS/stroop-effect.dmg
```

### Web

```bash
godot --path . --headless --export-release "Web"
```

Writes `build/web/index.html` alongside `index.wasm` and `index.pck`. The preset has thread support
off, so the build needs no COOP/COEP cross-origin-isolation headers and will run on any static host.
It cannot be opened over `file://` -- serve the directory instead:

```bash
python3 -m http.server 8000 --directory build/web
```

Then open <http://localhost:8000/>. Whatever server is used must send `.wasm` as
`application/wasm`, or the WebAssembly module will not stream-compile.

### Other targets

```bash
godot --path . --headless --export-release "Windows Desktop"
```

```bash
godot --path . --headless --export-release "Linux/X11"
```

Both of these presets write to `builds/` rather than `build/`, unlike macOS and Web.

Swap `--export-release` for `--export-debug` to get a build with the debugger attached and verbose
error reporting.

### Build output

`build/` is committed but empty: everything inside it is gitignored except `build/.gdignore`, whose
presence tells Godot to skip the folder entirely. Without that marker the previous export's icons
are re-imported as project resources and packed into the next build, which compounds every time.

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
- `src/terrain/obstacles/` - `obstacle.gd` plus the reusable obstacle prefabs (low, high, wide, moving, etc.)
- `src/controllers/` - TerrainController, CameraController, MusicController
- `src/globals/` - `game.gd` (autoload) and `color_util.gd`
- `src/player/` - `player.gd` and its component scripts (`trail.gd`, `puff_emitter.gd`, `sfx_player.gd`, `score_keeper.gd`, `timed_effect.gd`)
- `src/ui/` - one script per UI scene (`ui.gd`, `hud.gd`, `lose_ui.gd`, `pause_ui.gd`, `start_ui.gd`, `modifier_status.gd`)

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
2. Add obstacle instances from `src/terrain/obstacles/`
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
