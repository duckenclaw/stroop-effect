extends Node3D
class_name TerrainController

@onready var player = get_parent().get_node("Player")

@export var terrain_blocks: Array[PackedScene] = []  # Drag and drop terrain scenes here in the editor
@export var obstacle_materials: Array[ShaderMaterial] = []  # Drag and drop materials here in the editor

var terrain_belt: Array[MeshInstance3D] = []
var terrains_count: int = 0
var is_progressing: bool = false
@export var terrain_velocity: float = 7.5
@export var terrain_velocity_increase: float = 0.0025
@export var num_terrain_blocks = 10
@export var deletion_offset = 10
@export var start_block = load("res://src/terrain/terrains/terrain_free.tscn")
@export var color_change_block = load("res://src/terrain/terrains/terrain_color_change.tscn")
@export var color_change_frequency: int = 10

func _ready() -> void:
	if terrain_blocks.is_empty():
		push_error("No terrain blocks assigned! Please add terrain scenes to the TerrainController in the editor.")
	if obstacle_materials.is_empty():
		push_warning("No obstacle materials assigned. Obstacles will use their default materials.")
	_init_blocks(num_terrain_blocks)
	player.start_game.connect(_on_game_start)

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
			block = terrain_blocks.pick_random().instantiate()
			_append_to_far_edge(terrain_belt[block_index-1], block)
		add_child(block)
		terrain_belt.append(block)
		_assign_random_materials(block)  # Assign materials after adding block

func _progress_terrain(delta: float) -> void:
	for block in terrain_belt:
		block.position.z += (terrain_velocity + terrains_count/100.0) * delta

	if terrain_belt[0].position.z-deletion_offset >= terrain_belt[0].mesh.size.y/2:
		var last_terrain = terrain_belt[-1]
		var first_terrain = terrain_belt.pop_front()
		var block
		if terrains_count % color_change_frequency == 0:
			block = color_change_block.instantiate()
		else:
			block = terrain_blocks.pick_random().instantiate()
		_append_to_far_edge(last_terrain, block)
		add_child(block)
		terrain_belt.append(block)
		terrains_count += 1
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
		if obstacle.is_in_group("obstacle") or obstacle.is_in_group("collectible"):
			var mesh_instance = obstacle.get_node("Mesh")
			var random_material = obstacle_materials.pick_random()
			mesh_instance.material_override = random_material

func _on_player_lose():
	terrain_velocity = 0.0

func _on_game_start():
	is_progressing = true
