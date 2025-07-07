extends Node3D
class_name TerrainController

@onready var player = get_parent().get_node("Player")

var TerrainBlocks: Array = []
var terrain_belt: Array[MeshInstance3D] = []
var terrains_count: int = 0
@export var terrain_velocity: float = 7.5
@export var terrain_velocity_increase: float = 0.005
@export var num_terrain_blocks = 10
@export var deletion_offset = 10
@export var start_block = load("res://scenes/special_terrains/terrain_free.tscn")
@export var color_change_block = load("res://scenes/special_terrains/terrain_color_change.tscn")
@export var color_change_frequency: int = 10
@export_dir var terrian_blocks_path = "res://scenes/terrains/"
@export_dir var materials_path = "res://materials/obstacle_materials/"  # Path to obstacle materials

# Array to store loaded obstacle materials
var obstacle_materials: Array = []

func _ready() -> void:
	_load_terrain_scenes(terrian_blocks_path)
	_load_obstacle_materials(materials_path)
	_init_blocks(num_terrain_blocks)

func _physics_process(delta: float) -> void:
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
			block = TerrainBlocks.pick_random().instantiate()
			_append_to_far_edge(terrain_belt[block_index-1], block)
		add_child(block)
		terrain_belt.append(block)
		print(terrains_count)
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
			block = TerrainBlocks.pick_random().instantiate()
		_append_to_far_edge(last_terrain, block)
		add_child(block)
		terrain_belt.append(block)
		terrains_count += 1
		_assign_random_materials(block)  # Assign materials after adding block
		first_terrain.queue_free()

func _append_to_far_edge(target_block: MeshInstance3D, appending_block: MeshInstance3D) -> void:
	appending_block.position.z = target_block.position.z - target_block.mesh.size.y/2 - appending_block.mesh.size.y/2
	terrain_velocity += player.points * terrain_velocity_increase

func _load_terrain_scenes(target_path: String) -> void:
	var dir = DirAccess.open(target_path)
	for scene_path in dir.get_files():
		print("Loading terrain block scene: " + target_path + "/" + scene_path)
		TerrainBlocks.append(load(target_path + "/" + scene_path))

# Load all materials from the specified directory
func _load_obstacle_materials(target_path: String) -> void:
	var dir = DirAccess.open(target_path)
	for material_path in dir.get_files():
		var material = load(target_path + "/" + material_path)
		if material is Material:
			obstacle_materials.append(material)

# Randomly assign materials to each obstacle within the block
func _assign_random_materials(block: Node) -> void:
	for obstacle in block.get_children():
		if obstacle.name.ends_with("Obstacle") and not(obstacle.name.begins_with("Ramp")):  # Check for obstacle nodes
			if obstacle.has_node("Mesh"):  # Ensure there's a mesh instance
				var mesh_instance = obstacle.get_node("Mesh")
				var random_material = obstacle_materials.pick_random()
				mesh_instance.material_override = random_material

func _on_player_lose():
	terrain_velocity = 0.0
