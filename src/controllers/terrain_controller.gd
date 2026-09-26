class_name TerrainController
extends Node3D

## Points scored by terrain effects, rather than reaching into the player to add them directly.
signal points_awarded(amount: float)
## Fires as the player crosses a stage-change gate. current_stage flips earlier, when the gate is
## spawned at the far end of the belt, so anything the player should perceive -- the music -- waits
## for this instead.
signal stage_changed(stage: int)

@export var obstacle_materials: Array[ShaderMaterial] = []  # Drag and drop materials here in the editor

# Staged terrain blocks
@export var stage_1_blocks: Array[PackedScene] = []
@export var stage_2_blocks: Array[PackedScene] = []
@export var stage_3_blocks: Array[PackedScene] = []

var terrain_belt: Array[MeshInstance3D] = []
var terrains_count: int = 0
## Metres of terrain that have scrolled past the player since the run started.
var distance: float = 0.0
var current_stage: int = 1
var is_progressing: bool = false
## Mirrored from the player's points_changed signal; only used to ramp difficulty.
var score: float = 0.0
## Stage-change gates still ahead of the player, oldest first, as [block, stage] pairs.
var _stage_gates: Array = []
@export var terrain_velocity: float = 5.5
@export var terrain_velocity_increase: float = 0.0025
@export var num_terrain_blocks: int = 10
@export var deletion_offset: float = 10.0
@export var start_block: PackedScene = preload("res://src/terrain/terrains/special/terrain_free.tscn")
@export var color_change_block: PackedScene = preload("res://src/terrain/terrains/special/terrain_color_change.tscn")
@export var stage_change_block: PackedScene = preload("res://src/terrain/terrains/special/terrain_stage_change.tscn")
@export var color_change_frequency: int = 7
@export var stage_2_distance: float = 500.0  # Distance to reach stage 2
@export var stage_3_distance: float = 1000.0  # Distance to reach stage 3
@export var stage_4_distance: float = 1500.0  # Distance to reach stage 4

func _ready() -> void:
	if obstacle_materials.is_empty():
		push_warning("No obstacle materials assigned. Obstacles will use their default materials.")
	_init_blocks(num_terrain_blocks)

func _physics_process(delta: float) -> void:
	if is_progressing:
		_progress_terrain(delta)

func _init_blocks(number_of_blocks: int) -> void:
	for block_index in number_of_blocks:
		var block
		if block_index == 0:
			block = start_block.instantiate()
			block.position.z = block.mesh.size.y/2
		elif block_index == 1:
			block = start_block.instantiate()
			_append_to_far_edge(terrain_belt[block_index-1], block)
		else:
			var current_blocks = _get_current_stage_blocks() 
			block = current_blocks.pick_random().instantiate()
			_append_to_far_edge(terrain_belt[block_index-1], block)
		add_child(block)
		terrain_belt.append(block)
		terrains_count += 1
		_assign_random_materials(block)  # Assign materials after adding block

func get_scroll_speed() -> float:
	# How fast the world slides past the player, in m/s. Zero while the game is not running so
	# effects that follow the ground (the player's trail, its puffs) freeze with the terrain.
	if not is_progressing:
		return 0.0
	return terrain_velocity + terrains_count/100.0

func _progress_terrain(delta: float) -> void:
	var scroll := get_scroll_speed()
	for block in terrain_belt:
		block.position.z += scroll * delta
	distance += scroll * delta
	_announce_passed_gates()

	if terrain_belt[0].position.z-deletion_offset >= terrain_belt[0].mesh.size.y/2:
		var last_terrain = terrain_belt[-1]
		var first_terrain = terrain_belt.pop_front()
		var block

		# The new block starts at the belt's far edge, so this is the distance the player will have
		# travelled when they reach it. The gate sits on that near edge, so a gate spawned here is
		# crossed at the first block boundary at or past the stage threshold.
		var arrival_distance: float = distance - _far_edge(last_terrain)
		var next_stage = _calculate_stage_from_distance(arrival_distance)
		var is_stage_change = next_stage > current_stage and current_stage < 4

		if is_stage_change:
			block = stage_change_block.instantiate()
			current_stage = next_stage
			_stage_gates.append([block, next_stage])
		elif terrains_count % color_change_frequency == 0:
			block = color_change_block.instantiate()
		else:
			var current_blocks = _get_current_stage_blocks()
			block = current_blocks.pick_random().instantiate()

		_append_to_far_edge(last_terrain, block)
		add_child(block)
		terrain_belt.append(block)
		terrains_count += 1
		# Difficulty ramps with the score. Kept here rather than inside _append_to_far_edge, which
		# is a positioning helper and also runs while the starting belt is being built.
		terrain_velocity += score * terrain_velocity_increase
		_assign_random_materials(block)  # Assign materials after adding block
		first_terrain.queue_free()

## Emits stage_changed for every gate that has reached the player at z = 0. The gate model sits on
## the block's near edge, so that edge is what gets compared.
func _announce_passed_gates() -> void:
	while not _stage_gates.is_empty():
		var gate: MeshInstance3D = _stage_gates[0][0]
		if is_instance_valid(gate) and gate.position.z + gate.mesh.size.y/2 < 0.0:
			return  # still ahead; later gates are further ahead still
		var stage: int = _stage_gates.pop_front()[1]
		stage_changed.emit(stage)

## z of the block's edge furthest from the player.
func _far_edge(block: MeshInstance3D) -> float:
	return block.position.z - block.mesh.size.y/2

func _append_to_far_edge(target_block: MeshInstance3D, appending_block: MeshInstance3D) -> void:
	appending_block.position.z = _far_edge(target_block) - appending_block.mesh.size.y/2

# Randomly assign colors to each obstacle within the block
func _assign_random_materials(block: Node) -> void:
	if obstacle_materials.is_empty():
		return
	for child in block.get_children():
		if child.is_in_group("obstacle") or child.is_in_group("color-change"):
			apply_color(child, random_color_name())

## Picks from the editor-configured material list so the palette stays controllable per project.
func random_color_name() -> String:
	if obstacle_materials.is_empty():
		return ColorUtil.random_name()
	return ColorUtil.name_of(obstacle_materials.pick_random())

## Recolors an obstacle or a color-change collectible. Obstacles remember their color name;
## collectibles are scriptless, so they only get the material.
func apply_color(node: Node, color_name: String) -> void:
	if node is Obstacle:
		node.set_color(color_name)
		return
	var mesh_instance := node.get_node_or_null(^"Mesh") as MeshInstance3D
	if mesh_instance:
		mesh_instance.material_override = ColorUtil.material_for(color_name)

func _on_player_lose():
	# Zeroing terrain_velocity alone left get_scroll_speed() returning terrains_count/100, so the
	# world kept sliding after death.
	_set_progressing(false)

func _on_game_started() -> void:
	_set_progressing(true)

func _on_player_pause() -> void:
	_set_progressing(false)

func _on_player_unpause() -> void:
	_set_progressing(true)

func _on_player_points_changed(total: float, _modifier: float) -> void:
	score = total

func _set_progressing(value: bool) -> void:
	is_progressing = value

# Helper function to get terrain blocks for the current stage
func _get_current_stage_blocks() -> Array[PackedScene]:
	match current_stage:
		1:
			return stage_1_blocks
		2:
			return stage_2_blocks
		3, 4:
			return stage_3_blocks
		_:
			return stage_1_blocks

# Helper function to calculate which stage a distance corresponds to
func _calculate_stage_from_distance(dist: float) -> int:
	if dist >= stage_4_distance:
		return 4
	elif dist >= stage_3_distance:
		return 3
	elif dist >= stage_2_distance:
		return 2
	else:
		return 1

# Change obstacles in 5 terrains to match the player's color
func _on_match_color(color_name: String):
	for obstacle in _obstacles_in_terrains(5):
		obstacle.set_color(color_name)

# Dissolve all obstacles with matching color in 3 terrains
func _on_color_clear(color_name: String):
	for obstacle in _obstacles_in_terrains(3):
		if obstacle.color_name == color_name:
			obstacle.start_dissolve(obstacle.position)
			points_awarded.emit(1.0)

## Obstacles in the next `terrain_count` blocks the player has yet to reach.
##
## terrain_belt is ordered by descending z: index 0 is the block behind the player, about to be
## recycled. Slicing from the head therefore affected terrain that had already gone past, which
## is why color-match and color-clear appeared to do nothing.
func _obstacles_in_terrains(terrain_count: int) -> Array[Obstacle]:
	var obstacles: Array[Obstacle] = []
	var affected := 0
	for block in terrain_belt:
		if block.position.z >= 0.0:
			continue  # the player is at z = 0; anything at or past it is behind them
		if affected >= terrain_count:
			break
		affected += 1
		for child in block.get_children():
			if child is Obstacle:
				obstacles.append(child)
	return obstacles
