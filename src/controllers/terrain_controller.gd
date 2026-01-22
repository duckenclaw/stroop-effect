extends Node3D
class_name TerrainController

@onready var player = get_parent().get_node("Player")

@export var obstacle_materials: Array[ShaderMaterial] = []  # Drag and drop materials here in the editor

# Staged terrain blocks
@export var stage_1_blocks: Array[PackedScene] = []
@export var stage_2_blocks: Array[PackedScene] = []
@export var stage_3_blocks: Array[PackedScene] = []

var terrain_belt: Array[MeshInstance3D] = []
var terrains_count: int = 0
var distance: float = 0.0
var current_stage: int = 1
var is_progressing: bool = false
@export var terrain_velocity: float = 5.5
@export var terrain_velocity_increase: float = 0.0025
@export var num_terrain_blocks = 10
@export var deletion_offset = 10
@export var start_block = load("res://src/terrain/terrains/terrain_free.tscn")
@export var color_change_block = load("res://src/terrain/terrains/terrain_color_change.tscn")
@export var stage_change_block = load("res://src/terrain/terrains/terrain_stage_change.tscn")
@export var color_change_frequency: int = 7
@export var terrain_length: float = 10.0  # Length of each terrain in meters
@export var stage_2_distance: float = 500.0  # Distance to reach stage 2
@export var stage_3_distance: float = 1000.0  # Distance to reach stage 3
@export var stage_4_distance: float = 1500.0  # Distance to reach stage 4

func _ready() -> void:
	if obstacle_materials.is_empty():
		push_warning("No obstacle materials assigned. Obstacles will use their default materials.")
	_init_blocks(num_terrain_blocks)
	player.start_game.connect(_on_game_start)
	player.pause.connect(_on_game_pause)
	player.unpause.connect(_on_game_unpause)
	player.match_color.connect(_on_match_color)
	player.color_clear.connect(_on_color_clear)

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

func _progress_terrain(delta: float) -> void:
	for block in terrain_belt:
		block.position.z += (terrain_velocity + terrains_count/100.0) * delta

	if terrain_belt[0].position.z-deletion_offset >= terrain_belt[0].mesh.size.y/2:
		var last_terrain = terrain_belt[-1]
		var first_terrain = terrain_belt.pop_front()
		var block

		# Calculate what the distance will be after spawning the next terrain
		var next_distance = (terrains_count + 1) * terrain_length

		# Check if this terrain spawning will cross a stage threshold
		var next_stage = _calculate_stage_from_distance(next_distance)
		var is_stage_change = next_stage > current_stage and current_stage < 4
		
		if is_stage_change:
			# Spawn stage change block at the exact distance threshold
			block = stage_change_block.instantiate()
			current_stage = next_stage
		elif terrains_count % color_change_frequency == 0:
			block = color_change_block.instantiate()
		else:
			var current_blocks = _get_current_stage_blocks()
			block = current_blocks.pick_random().instantiate()

		_append_to_far_edge(last_terrain, block)
		add_child(block)
		terrain_belt.append(block)
		terrains_count += 1
		distance = (terrains_count - num_terrain_blocks) * terrain_length  # Update distance
		_assign_random_materials(block)  # Assign materials after adding block
		first_terrain.queue_free()

func _append_to_far_edge(target_block: MeshInstance3D, appending_block: MeshInstance3D) -> void:
	appending_block.position.z = target_block.position.z - target_block.mesh.size.y/2 - appending_block.mesh.size.y/2
	terrain_velocity += player.points * terrain_velocity_increase

# Randomly assign materials to each obstacle within the block
func _assign_random_materials(block: Node) -> void:
	if obstacle_materials.is_empty():
		return
	for obstacle in block.get_children():
		if obstacle.is_in_group("obstacle") or obstacle.is_in_group("color-change"):
			var mesh_instance = obstacle.get_node("Mesh")
			var random_material = obstacle_materials.pick_random()
			mesh_instance.material_override = random_material

func _on_player_lose():
	terrain_velocity = 0.0

func _on_game_start():
	is_progressing = true

func _on_game_pause():
	is_progressing = false

func _on_game_unpause():
	is_progressing = true

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

func _on_match_color(color_name: String):
	# Load the material for the specified color
	var material_file = player.materials_path + "/" + color_name + ".tres"
	var material = load(material_file)

	if material == null:
		push_warning("Could not load material: " + material_file)
		return

	# Change obstacles in the next 5 terrains to match the player's color
	var terrains_to_affect = min(5, terrain_belt.size())
	for i in range(terrains_to_affect):
		var terrain = terrain_belt[i]
		for obstacle in terrain.get_children():
			if obstacle.is_in_group("obstacle") or obstacle.is_in_group("collectible"):
				var mesh_instance = obstacle.get_node("Mesh")
				mesh_instance.material_override = material

func _on_color_clear(color_name: String):
	# Load the material for the specified color
	var material_file = player.materials_path + "/" + color_name + ".tres"
	var material = load(material_file)

	if material == null:
		push_warning("Could not load material: " + material_file)
		return

	# Dissolve all obstacles with matching color in the next 3 terrains
	var terrains_to_affect = min(3, terrain_belt.size())
	for i in range(terrains_to_affect):
		var terrain = terrain_belt[i]
		for obstacle in terrain.get_children():
			if obstacle.is_in_group("obstacle"):
				var mesh_instance = obstacle.get_node("Mesh")
				var obstacle_material = mesh_instance.get_active_material(0)

				# Check if the obstacle's material matches the player's color
				if obstacle_material == material:
					var collision_point = obstacle.position
					obstacle.start_dissolve(collision_point)
					player.add_points(1.0)
