extends Camera3D

# Menu and gameplay camera positions/rotations
const MENU_POSITION := Vector3(-2.0, 2.0, -2.0)
const MENU_ROTATION := Vector3(-25.0, -135.0, 0.0)  # In degrees
const GAMEPLAY_POSITION := Vector3(0.0, 4.0, 4.0)
const GAMEPLAY_ROTATION := Vector3(-25.0, 0.0, 0.0)  # In degrees
const TRANSITION_DURATION := 0.8  # Smooth transition time in seconds

# Screen shake constants
const TRAUMA_DECAY := 1.5  # Trauma reduction per second
const MAX_OFFSET := 0.3  # Maximum position offset in units
const MAX_ROTATION := 3.0  # Maximum rotation offset in degrees

# Screen shake state
var trauma := 0.0  # Current trauma level (0.0 to 1.0)
var base_position := Vector3.ZERO  # Store base position for shake offset
var base_rotation := Vector3.ZERO  # Store base rotation for shake offset

signal transition_complete

func _ready():
	# Set camera to menu position at startup
	position = MENU_POSITION
	rotation_degrees = MENU_ROTATION
	base_position = position
	base_rotation = rotation_degrees

func transition_to_gameplay() -> void:
	# Create tween for smooth camera transition
	var tween = create_tween()
	tween.set_parallel(true)  # Animate position and rotation simultaneously
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	# Animate position
	tween.tween_property(self, "position", GAMEPLAY_POSITION, TRANSITION_DURATION)

	# Animate rotation
	tween.tween_property(self, "rotation_degrees", GAMEPLAY_ROTATION, TRANSITION_DURATION)

	# Update base position/rotation for shake system
	base_position = GAMEPLAY_POSITION
	base_rotation = GAMEPLAY_ROTATION

	# Emit signal when transition completes
	tween.finished.connect(_on_transition_finished)

func _on_transition_finished() -> void:
	transition_complete.emit()

func _process(delta: float) -> void:
	# Decay trauma over time
	if trauma > 0.0:
		trauma = max(trauma - TRAUMA_DECAY * delta, 0.0)

		# Calculate shake intensity using trauma squared for smoother falloff
		var shake_intensity = trauma * trauma

		# Generate random offsets based on shake intensity
		var offset_x = randf_range(-1.0, 1.0) * MAX_OFFSET * shake_intensity
		var offset_y = randf_range(-1.0, 1.0) * MAX_OFFSET * shake_intensity
		var offset_z = randf_range(-1.0, 1.0) * MAX_OFFSET * shake_intensity

		var rotation_x = randf_range(-1.0, 1.0) * MAX_ROTATION * shake_intensity
		var rotation_y = randf_range(-1.0, 1.0) * MAX_ROTATION * shake_intensity
		var rotation_z = randf_range(-1.0, 1.0) * MAX_ROTATION * shake_intensity

		# Apply shake to camera
		position = base_position + Vector3(offset_x, offset_y, offset_z)
		rotation_degrees = base_rotation + Vector3(rotation_x, rotation_y, rotation_z)
	else:
		# Reset to base position when no trauma
		position = base_position
		rotation_degrees = base_rotation

func add_trauma(amount: float) -> void:
	"""Add trauma to the camera shake system. Amount should be between 0.0 and 1.0."""
	trauma = min(trauma + amount, 1.0)

func _on_collision_shake() -> void:
	"""Called when player collides with wrong color obstacle."""
	add_trauma(0.45)

func _on_slam_shake() -> void:
	"""Called when player's slam ends."""
	add_trauma(0.35)
