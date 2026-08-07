extends Node
## Handles to the main scene's systems.
##
## Without this, every system finds every other one by walking the tree with hardcoded relative
## paths -- get_parent().get_parent().get_node("Player") and friends -- so renaming a node in
## world.tscn silently breaks several files at once. The fragility isn't gone, but it is now in
## one place instead of five.
##
## This holds no game state on purpose: the score belongs to the player, the stage to the terrain
## controller. It is a lookup table, not a blackboard.

const FALLBACK_SCROLL_SPEED := 5.5  # used only if TerrainController isn't reachable

const PLAYER_PATH := ^"Player"
const TERRAIN_PATH := ^"TerrainController"
const UI_PATH := ^"CanvasLayer/UI"
const CAMERA_PATH := ^"Camera"

var player: Player:
	get: return _resolve(PLAYER_PATH) as Player

var terrain: TerrainController:
	get: return _resolve(TERRAIN_PATH) as TerrainController

var ui: Node:
	get: return _resolve(UI_PATH)

var camera: CameraController:
	get: return _resolve(CAMERA_PATH) as CameraController

## How fast the world slides past the player, in m/s. Lives here because the player's trail and its
## puffs both need it to travel with the ground, and neither should have to know how to find the
## terrain controller. Still a lookup, not state -- the number belongs to TerrainController.
func scroll_speed() -> float:
	var controller := terrain
	if controller:
		return controller.get_scroll_speed()
	return FALLBACK_SCROLL_SPEED

var _cache: Dictionary = {}

## Resolution is lazy because current_scene is still null when an autoload readies, and the cache
## is validity-checked rather than cleared so it heals itself across reload_current_scene().
func _resolve(path: NodePath) -> Node:
	var cached = _cache.get(path)
	if is_instance_valid(cached):
		return cached
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var node := scene.get_node_or_null(path)
	_cache[path] = node
	return node
