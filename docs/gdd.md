---
class: gdd
genre:
  - platform
  - arcade
game-themes:
  - psychedelic
platforms:
  - Web
game-engine: Godot
game-modes: Singleplayer
graphics: 3D
player-perspective: 3rd person
---

# Overview

---

**Stroop Effect** is a 3D endless runner built in Godot 4.6 for the web. The player is a cube that runs forward down a three-lane track while the world scrolls past it. The player always *has* a color; so does every obstacle. Matching colors destroy each other. Mismatched colors kill.

The twist the game is named for lives in the HUD: the player's current color is shown as a **word** at the top of the screen, rendered in a font color that cycles continuously through a rainbow and is almost never the color the word names. Reading "RED" printed in flashing cyan while a green wall closes in is the cognitive load the whole design is built around.

> This document describes the game **as it is currently built**. Values are taken from the source, not from intent.

## Gameplay

The player runs forward automatically. There is no speed control and no way to stop. Three inputs matter: switch lane, jump, and slam.

Obstacles arrive in a continuous stream. Each one is blue, green, or red. So is the player.

- **Obstacle color matches the player's** — running into it destroys it in a neon dissolve and scores a point.
- **Obstacle color does not match** — running into it ends the run immediately.
- **Slamming down onto a matching obstacle** from the air destroys it *and* bounces the player upward at 1.5× normal jump velocity, which is the only way to reach the higher pickups.
- **Slamming down onto a mismatched obstacle** is harmless — the player simply plays a jump animation and does not die. Only the front hitbox is lethal.

The player's color changes only by collecting a Color Change pickup, which also raises the score multiplier. Everything else in the run is about surviving long enough for that multiplier to matter.

The run ends on a single mismatched collision. There are no lives and no checkpoints.

## Story and setting

There is none. The game has no narrative, no characters, and no text beyond the HUD, the menu, and the tutorial panel. It is a pure arcade score-attack.

## Art theme

Psychedelic, and almost entirely procedural — there are very few authored textures in the project.

**Sky.** `assets/resources/world.gdshader` is a `shader_type sky` shader with **no uniforms at all**. It derives everything from `EYEDIR` and `TIME`. Three sine/cosine interference patterns and one rotating spiral term are averaged together into a single scalar, which then drives two RGB triples phase-offset by 2π/3 and π/3. Those are cross-faded against each other by `sin(TIME * 0.4)` and gamma-corrected with `pow(c, 0.9)` to push saturation. The result is a slowly churning rainbow swirl that fills the entire background.

**Ground.** `assets/resources/materials/terrain.tres` is a `StandardMaterial3D` with `metallic = 1.0` and `roughness = 0.0` — a perfect mirror, tinted cyan and semi-transparent. It reflects the sky shader, so the floor is a moving rainbow too. The playfield is a rainbow sandwiched between two rainbows.

**Objects.** Every colored object uses `outline.gdshader`, an inverted-hull outline: `render_mode cull_front`, `VERTEX += NORMAL * outline_thickness` in the vertex stage, flat `outline_color` in the fragment stage. The outline color is black on all materials. The *visible* color comes from `next_pass`, which points at a `StandardMaterial3D` in `obstacle-materials/` whose color lives in an albedo texture. This gives everything a hard black cel outline against the chaos behind it.

**Destruction.** `dissolve.gdshader` cuts a growing sphere out of the mesh. It computes world position via `INV_VIEW_MATRIX`, measures distance to `sphere_position`, perturbs that radius with noise, and `discard`s everything inside. Within `burn_threshold` of the cut edge it runs a three-layer power-ramp stack into `EMISSION`, producing a neon burn rim that reads as bright even in `gl_compatibility`. Back faces get an extra neon pass at 1.5× intensity, so you see the object glowing from the inside as it opens up.

**Stage gates.** `shaders/electric_field.gdshader` — additive, unshaded, four-octave fractal noise. One noise layer is a general shimmer; a second is stretched vertically and scrolled to read as lightning bolts. A fresnel term brightens the edges and a `sin(TIME * flicker_speed)` term makes it flicker. Applied to a 7×7 quad inside the gate arch that marks each stage transition.

**UI.** Deliberately opposed to all of the above: stark 1-bit chrome. `PixeloidMono.ttf` throughout, pure black panels with 4px pure white borders and hard drop shadows (`main-theme.tres`). The only color in the UI is the rainbow cycling on the Stroop word and on the score multiplier.

## Sound design

Minimal, and incomplete.

**Buses:** Master, Music, SFX (`assets/sound/default_bus_layout.tres`), all at 0 dB with no effects.

**There is no background music.** `music_controller.gd` exports a `bgm` field, but it is never assigned in `world.tscn` and never read by any code. The node it lives on has `autoplay = true` with no stream, so autoplay does nothing. The Music bus carries exactly one sound: `wika-wika.mp3`, a death sting played on `lose`. `electric-spiral.mp3` is committed to the repo and referenced by nothing.

**SFX:** two clips total — `score.mp3` (obstacle destroyed) and `color_change.mp3` (any of the five pickups). Both play through a single `AudioStreamPlayer3D` on the player at `-5 dB`, whose `stream` is reassigned before each play. Because it is one voice, overlapping pickups cut each other off.

There are no jump, landing, lane-switch, or UI sounds.

The Options menu exposes Master / Music / SFX sliders that map `value / 100.0` through `linear_to_db()` onto bus indices 0/1/2. Two of the three control buses that are nearly empty.

---

# Mechanics

---

## Player

`src/player/player.gd`, a `CharacterBody3D`.

### Movement

| Property | Value | Notes |
|---|---|---|
| Lane positions | `[-2.0, 0.0, 2.0]` | X axis; starts in the center (index 1) |
| Lane lerp speed | `MOVE_SPEED = 7.5` | Exponential lerp toward the target X each physics frame |
| Jump velocity | `JUMP_VELOCITY = 5.5` | |
| Gravity | `12.0` | Project setting, well above Earth's 9.8 for a snappier arc |
| Slam impulse | `gravity * DOWN_SPEED (100.0) * delta` | Applied for one frame on slam press |
| Slam bounce | `JUMP_VELOCITY * 1.5` = `8.25` | Only on a color-matched slam |
| Flight hover height | `FLIGHT_HEIGHT = 2.0` | |

The player's Z position is lerped back to `0.0` every frame — it never actually travels forward. The terrain moves instead.

Slam requires being airborne and not already slamming. On landing, a downward `RayCast3D` reports what was hit; that is what distinguishes a slam-destroy from an ordinary landing.

### Color

Three colors ship: **blue**, **green**, **red**. These are discovered at runtime by scanning `assets/resources/materials/outline-materials/` for `ShaderMaterial` resources and taking their filenames. That directory contains exactly those three.

(`player.gd`'s `COLOR_VALUES` dictionary lists six — blue, green, red, orange, yellow, purple — and outline materials for orange, purple, and yellow do exist, but one directory higher, outside the scanned folder. They are unreachable. `terrain_controller.tscn` likewise assigns only the three.)

The color is picked at random in `_ready()` and changes only via the Color Change pickup. Changing color:

1. Sets the mesh's `material_override` to the matching outline material.
2. Recomputes a "vivid" tint — the stored albedo averages are dark, so they are normalized by their peak channel to full brightness — and applies it to the wind puffs and the speed trail.
3. Pushes the new color name to the HUD.

**Color comparison is done by resource filename.** An obstacle's color is recovered with `mesh.get_active_material(0).get_path().get_file().get_basename()`, yielding `"blue"`, `"green"`, or `"red"`. The material file's name *is* the color identity.

### Scoring

```
points += amount * point_modifier
```

Every scoring event awards a base `amount` of **1.0**: passing through a matched obstacle, slam-destroying one, clearing one with Color Clear, and picking up any collectible.

The multiplier starts at `1.0` and rises by `modifier_multipier` (default `1.0`) each time a Color Change is collected, toward a ceiling of `5.0`. It resets to `1.0` after `STREAK_DECAY = 3.5` seconds without a scoring event. The HUD shows it only while it is above 1.

### VFX

**Wind puffs** — a single `CPUParticles3D` serves every event, reconfigured from one of five presets immediately before `restart()`: `lane_left`, `lane_right`, `jump`, `slam_start`, `slam_land`. Each preset defines direction, emission height, particle count, spread, lifetime, velocity range, gravity, scale range, and emission radius. Presets flagged `drift` have their gravity's Z component overwritten with the current scroll speed, so the puff travels backward with the ground instead of hanging in world space. Additive blend, tinted with the player's vivid color.

**Speed trail** — a camera-facing ribbon built every physics frame into an `ImmediateMesh`. It stores the last 28 world-space positions (~0.45 s at 60 Hz) and pushes each stored point backward at the scroll speed, which is what turns a nearly-stationary player into a visible streak. The ribbon tapers from `TRAIL_WIDTH = 0.22` at the head to zero at the tail and fades out along its length. The `Trail` node is `top_level`, so it does not inherit the player's transform.

## Obstacles

`src/terrain/obstacle.gd`, on a `StaticBody3D`. Nine scenes in `src/terrain/obstacle-scenes/`:

| Scene | Hitbox extents | Behavior |
|---|---|---|
| `low_obstacle` | 1 × 0.8 × 1 | Jump or destroy |
| `high_obstacle` | 1 × 1.8 × 1 | Too tall to clear casually |
| `long_obstacle` | 1 × 0.8 × 3 | Extended along Z |
| `long_high_obstacle` | 1 × 1.8 × 3 | Tall and long |
| `wide_obstacle` | 4 × 0.8 × 1 | Covers roughly two lanes |
| `ultrawide_obstacle` | 7 × 0.8 × 1 | Covers all three lanes — must be destroyed or jumped |
| `hmoving_obstacle` | 1 × 0.8 × 1 | Strafes X from 0 → 4 → 0 on a 5 s loop |
| `vmoving_obstacle` | 1 × 0.8 × 1 | Rises and falls Y 0.6 → 3.6 → 0.6 on a 3 s loop |
| `ramp` | *(none)* | Pure geometry |

Each scripted obstacle carries **two** colliders with different jobs:

- `Collider` — a thin slab on the top face, part of the `StaticBody3D`. This is what the player lands and slams on.
- `Hitbox/Collider` — a full-body `Area3D` trigger. This is what kills or gets destroyed on frontal contact.

**`ramp` is the exception to everything.** It has no script, no `obstacle` group, no hitbox, and uses the player material rather than a color material. It is never recolored and cannot be destroyed. It exists purely to launch the player upward.

Obstacles never choose their own color. Color is pushed in from `TerrainController` at spawn, and can be overwritten later by Color Match.

### Dissolve

`start_dissolve(collision_point)` frees both colliders, points the dissolve shader's `sphere_position` at the contact point, swaps the mesh material, and starts growing `sphere_radius` from `0.001` at `6.5` units/second. Past `10.0` the node frees itself.

## Collectibles

Spawned by `collectible.gd`, a weighted random spawner placed inside terrain blocks. It takes parallel arrays of scenes and weights plus a `nothing_weight`, so a spawn point can roll empty. The selected scene is instantiated as a child of the spawner.

Detection is by global group on an `Area3D`. All five award 1 point and play the pickup sound.

| Pickup | Group | Effect |
|---|---|---|
| **Color Change** | `color-change` | Sets the player's color to the pickup's own color, and raises the score multiplier one step toward 5.0. This is the only way to change color. |
| **Color Match** | `color-match` | Recolors every obstacle across 5 terrain blocks to the player's current color, making them all destructible. |
| **Color Clear** | `color-clear` | Immediately dissolves every obstacle matching the player's color across 3 terrain blocks, scoring a point for each. |
| **Double Jump** | `double-jump` | Enables jumping while airborne for **5.0 seconds**. |
| **Flight** | `flight` | For **10.0 seconds**, jumping makes the player levitate at `FLIGHT_HEIGHT = 2.0` instead of arcing — effectively a fourth, vertical lane. Slamming drops back to the ground and cancels levitation. |

Both timed pickups surface a radial countdown widget in the top-right of the HUD.

Color Change is the pickup the run revolves around: it is the only source of multiplier growth and the only way to make a differently-colored wall survivable. Color Clear is placed in exactly one terrain scene, so it is effectively unshipped content.

---

# Gameplay Loop

---

## Terrain belt

`src/controllers/terrain_controller.gd`. The world is an infinite scrolling belt of **10** terrain blocks.

Every physics frame, all 10 blocks translate along +Z at:

```
scroll_speed = terrain_velocity + terrains_count / 100.0
```

`terrain_velocity` starts at `5.5` and grows by `player.points * terrain_velocity_increase` each time a block is appended. Because it scales with the score, and the score scales with the multiplier, a good run accelerates superlinearly. The `terrains_count / 100.0` term adds a slower floor that rises with distance regardless of skill.

When the front block passes the deletion threshold it is freed and a new one is appended at the far edge. The choice of what to append is a strict priority:

1. **Stage change gate** — if appending this block would cross a stage distance threshold, and the game is not already at stage 4.
2. **Color change block** — every 7th block (`terrains_count % color_change_frequency == 0`).
3. **A random block from the current stage's pool.**

Note that priority 1 preempts priority 2 — the color-change cadence is silently skipped on any block a stage gate consumes.

## Stages

Three block pools of increasing difficulty, cumulative:

| Stage | Pool size | Contents |
|---|---|---|
| 1 | 10 blocks | all of `stage1/` |
| 2 | 14 blocks | 7 from `stage1/` + all 7 of `stage2/` |
| 3 | 18 blocks | 7 from `stage1/` + 7 from `stage2/` + all 4 of `stage3/` |

Stage 4 reuses the stage 3 pool — reaching it changes nothing except that no further gates spawn. Three stage-1 blocks (`terrain_18`, `terrain_19`, `terrain_20`) appear only in the stage 1 pool and vanish permanently once stage 2 begins.

**Thresholds as actually configured** in `world.tscn`, which overrides the script defaults of 500 / 1000 / 1500:

| Stage | Distance |
|---|---|
| 2 | 50 |
| 3 | 500 |
| 4 | 750 |

Distance is reported as `(terrains_count - num_terrain_blocks) * terrain_length` with `terrain_length = 10.0`. Note this is a block count scaled by a nominal length, not a measurement — the actual terrain meshes are 15 units long (20 for the special blocks), so the displayed number and the world are on different scales.

Crossing a threshold spawns the gate block: an arch mesh with the electric field quad stretched across it. Running through it is purely cosmetic.

## Run structure

1. Boot into `world.tscn`. The start menu is a layer inside the UI, not a separate scene — the camera sits at a three-quarter angle looking at the idle player.
2. Press Start. The menu hides, the HUD appears, player physics enables, terrain begins scrolling, and the camera tweens over 0.8 s from `(-2, 2, -2)` to the gameplay position `(0, 4, 4)`. There is no scene load, so the transition is seamless.
3. Run. Dodge, destroy, collect, chase the multiplier while the world speeds up.
4. Touch one mismatched obstacle. Player physics halts, terrain velocity zeroes, the death sting plays, and the results screen shows final score and distance.
5. Restart reloads the scene.

The camera shakes on a trauma model — `0.45` trauma added on any obstacle collision, `0.35` on a slam landing, decaying at `1.5`/second, driving up to `0.3` units of offset and 3° of rotation.

---

# Controls

---

| Action | Keys |
|---|---|
| Jump / levitate | `Space`, `W`, `↑` |
| Move left | `A`, `←` |
| Move right | `D`, `→` |
| Slam | `S`, `↓` |
| Pause | `Esc` |
| Restart (after death) | `R` |

Lane switching is clamped at both ends — there is no wraparound. Jump, slam, and lane switching are all read as `just_pressed`, so holding a key does nothing.

A `tutorial` action bound to `T` is defined in the InputMap but is not referenced by any script. (The tutorial panel on the start menu is opened by a button, not by that key.)

Pause is handled on the player: it toggles the player's physics processing and shows the results screen. It does not use Godot's scene-tree pause, so the camera shake, in-flight dissolves, and HUD countdown timers continue to run while paused.

---

# Technical Reference

---

## Scene graph

`src/world.tscn` is the main scene and the only scene ever loaded.

```
World (Node3D)
├── CanvasLayer
│   └── UI                    ui.gd  →  HUD / LoseUI / StartUI
├── TerrainController         terrain_controller.gd
├── WorldEnvironment          sky = world.gdshader
├── DirectionalLight3D        energy 2.5, indirect 3.0
├── Camera                    camera_controller.gd, far = 150
├── Player                    player.gd
├── AudioListener3D
└── AudioStreamPlayer3D       music_controller.gd, Music bus
```

There are no autoloads. Systems locate each other by walking the scene tree with hardcoded node names — the UI reaches the player via `get_parent().get_parent().get_node("Player")`, the terrain controller via `get_parent().get_node("Player")`, and the collectible spawner by walking its whole ancestor chain looking for a `TerrainController`. Renaming a node in `world.tscn` breaks several files at once.

## Signal wiring

The player is the event source for almost everything. Its signals: `lose`, `start_game`, `pause`, `unpause`, `match_color`, `color_clear`, `double_jump_started/ended`, `flight_started/ended`, `collision_with_obstacle`, `slam_ended`.

Wiring is split across two places, which is worth knowing when tracing behavior:

- **In `world.tscn`** — only `lose`, connected to three receivers (UI, TerrainController, music player).
- **In code** — everything else, across two different `_ready()` bodies. `terrain_controller.gd` connects five player signals; `ui.gd` connects six more, including two that forward player events straight to the camera's shake handlers.

Two inversions of ownership are worth noting: `ui.gd` emits `player.start_game` on the player's behalf and calls `player.set_physics_process(true)` directly, and `player.gd` calls UI update methods directly rather than emitting.

## Shaders

| Shader | Type | Key uniforms |
|---|---|---|
| `outline.gdshader` | spatial, `cull_front` | `outline_color`, `outline_thickness` (0.03–0.05) |
| `dissolve.gdshader` | spatial, `cull_disabled` | `sphere_position`, `sphere_radius`, `burn_threshold`, `noise_texture`, `noise_strength`, `noise_scale`, `neon_base_color`, `albedo_color`, `inner_face_neon_intensity` |
| `world.gdshader` | sky | *none* — fully procedural from `EYEDIR` and `TIME` |
| `shaders/electric_field.gdshader` | spatial, `blend_add`, unshaded | `field_color`, `animation_speed`, `field_intensity`, `edge_brightness`, `noise_scale`, `flicker_speed` |
| `wireframe.gdshader` | spatial, unshaded | `modelColor`, `wireframeColor`, `width`, `modelOpacity`, `filtered` — *unused; no material or scene references it* |

## Color convention

Color identity is a **string equal to the material's filename**. `blue.tres` is the color "blue".

- Terrain assignment: `TerrainController` picks a random material from its `obstacle_materials` array and writes it to the obstacle's `Mesh.material_override`.
- Recovery: `mesh.get_active_material(0).get_path().get_file().get_basename()`.
- Application: `load(materials_path + "/" + color_name + ".tres")`.

Color Clear compares by resource identity rather than by name, which works because `load()` returns the same cached instance that was assigned at spawn.

The outline materials themselves carry a black `outline_color`; the visible color comes from `next_pass` → `obstacle-materials/<color>.tres`, whose color is stored in an albedo *texture*. There is therefore no `Color` value readable from the material at runtime, which is why `player.gd` hardcodes a `COLOR_VALUES` table to tint the puffs and trail.

## Groups

Global groups declared in `project.godot`: `double-jump`, `color-clear`, `color-change`, `color-match`, `flight`.

`obstacle` is used pervasively but is not declared globally. It is applied to **both** the obstacle's `StaticBody3D` root and its `Area3D` hitbox, so `is_in_group("obstacle")` means different things depending on which node the caller is holding — the slam raycast hits the root, while the player's hitbox overlap reports the Area3D and has to call `get_parent()`.

## Rendering and export

`gl_compatibility` on both desktop and mobile, chosen for web export. Viewport 1600×900. No post-processing of any kind — the environment sets a sky and nothing else. Export presets exist for macOS, Windows, Linux/X11, iOS, and Web; the web build targets `build/web/index.html` with threads disabled.
