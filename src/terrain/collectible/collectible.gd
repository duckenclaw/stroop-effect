extends Node3D

## Weighted collectible spawner
## Place this node in terrain blocks and configure which collectibles can spawn
## with their respective weights for random selection

@export var collectible_scenes: Array[PackedScene] = []
@export var spawn_weights: Array[float] = []
@export var nothing_weight: float = 0.0


func _ready() -> void:
	_spawn_collectible()


func _spawn_collectible() -> void:
	# Validate configuration
	if collectible_scenes.size() != spawn_weights.size():
		push_error("collectible_scenes and spawn_weights arrays must have the same length")
		queue_free()
		return

	# Check for negative weights
	for weight in spawn_weights:
		if weight < 0:
			push_warning("Negative weight detected in spawn_weights - treating as 0")

	if nothing_weight < 0:
		push_warning("Negative nothing_weight detected - treating as 0")

	# Select a collectible using weighted random
	var selected_scene = _weighted_random_selection()

	# Spawn the selected collectible (if not nothing)
	if selected_scene != null:
		var collectible_instance = selected_scene.instantiate()
		print("selected scene: " + collectible_instance.name)

		# Add as child of this spawner node
		add_child(collectible_instance)


func _weighted_random_selection() -> PackedScene:
	# Calculate total weight
	var total_weight: float = nothing_weight
	for weight in spawn_weights:
		total_weight += max(0.0, weight)  # Clamp negative weights to 0

	# If total weight is 0, spawn nothing
	if total_weight <= 0:
		return null

	# Generate random value in range [0, total_weight)
	var random_value = randf() * total_weight

	# Check if "nothing" was selected
	if random_value < nothing_weight:
		return null

	# Subtract nothing_weight from random value
	random_value -= nothing_weight

	# Iterate through collectible weights using cumulative approach
	for i in range(collectible_scenes.size()):
		var weight = max(0.0, spawn_weights[i])
		random_value -= weight

		if random_value <= 0:
			return collectible_scenes[i]

	# Fallback (should never reach here due to math, but handle edge cases)
	return null
