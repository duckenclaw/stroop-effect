extends Camera3D

# Menu and gameplay camera positions/rotations
const MENU_POSITION := Vector3(-2.0, 2.0, -2.0)
const MENU_ROTATION := Vector3(-25.0, -135.0, 0.0)  # In degrees
const GAMEPLAY_POSITION := Vector3(0.0, 4.0, 4.0)
const GAMEPLAY_ROTATION := Vector3(-25.0, 0.0, 0.0)  # In degrees
const TRANSITION_DURATION := 0.8  # Smooth transition time in seconds

signal transition_complete

func _ready():
	# Set camera to menu position at startup
	position = MENU_POSITION
	rotation_degrees = MENU_ROTATION

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

	# Emit signal when transition completes
	tween.finished.connect(_on_transition_finished)

func _on_transition_finished() -> void:
	transition_complete.emit()
