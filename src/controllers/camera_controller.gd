class_name CameraController
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
var base_position := Vector3.ZERO  # Pose the shake offsets are measured from
var base_rotation := Vector3.ZERO

# While the menu-to-gameplay tween runs it owns position/rotation_degrees outright. Shaking during
# the transition would fight it, and updating base_* up front made any trauma snap the camera
# straight to the gameplay pose.
var _is_transitioning := false

signal transition_complete

func _ready():
	# Set camera to menu position at startup
	position = MENU_POSITION
	rotation_degrees = MENU_ROTATION
	base_position = position
	base_rotation = rotation_degrees
	# Nothing to shake yet; add_trauma() turns processing back on when there is.
	set_process(false)

func transition_to_gameplay() -> void:
	_is_transitioning = true
	var tween := create_tween()
	tween.set_parallel(true)  # Animate position and rotation simultaneously
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "position", GAMEPLAY_POSITION, TRANSITION_DURATION)
	tween.tween_property(self, "rotation_degrees", GAMEPLAY_ROTATION, TRANSITION_DURATION)
	tween.finished.connect(_on_transition_finished)

func _on_transition_finished() -> void:
	# Adopt the pose the tween actually landed on, then hand control back to the shake.
	base_position = GAMEPLAY_POSITION
	base_rotation = GAMEPLAY_ROTATION
	_is_transitioning = false
	set_process(trauma > 0.0)
	transition_complete.emit()

func _process(delta: float) -> void:
	if _is_transitioning:
		return

	trauma = maxf(trauma - TRAUMA_DECAY * delta, 0.0)
	if trauma <= 0.0:
		# One last write to settle back onto the base pose, then stop burning a frame callback for
		# the rest of the run.
		position = base_position
		rotation_degrees = base_rotation
		set_process(false)
		return

	# Trauma squared gives a smoother falloff than trauma alone.
	var shake_intensity := trauma * trauma
	position = base_position + _random_offset(MAX_OFFSET * shake_intensity)
	rotation_degrees = base_rotation + _random_offset(MAX_ROTATION * shake_intensity)

func _random_offset(magnitude: float) -> Vector3:
	return Vector3(
		randf_range(-1.0, 1.0) * magnitude,
		randf_range(-1.0, 1.0) * magnitude,
		randf_range(-1.0, 1.0) * magnitude,
	)

## Add trauma to the camera shake system. Amount should be between 0.0 and 1.0.
func add_trauma(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)
	if not _is_transitioning:
		set_process(true)

## Called when the player collides with a wrong-color obstacle.
func _on_collision_shake() -> void:
	add_trauma(0.45)

## Called when the player's slam ends.
func _on_slam_shake() -> void:
	add_trauma(0.35)
