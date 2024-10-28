extends CharacterBody3D

const SPEED = 7.5
const JUMP_VELOCITY = 6.5
const TRACK_POSITIONS = [-2.0, 0.0, 2.0]  # Left, Center, Right tracks along the X-axis
const MOVE_SPEED = 7.5  # Speed of lerping between tracks

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var current_track = 1  # Start at the center track (0 = left, 1 = center, 2 = right)

signal lose()

func _physics_process(delta):
	# Add gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Handle track switching with input.
	if Input.is_action_just_pressed("ui_left") and current_track > 0:
		current_track -= 1
	elif Input.is_action_just_pressed("ui_right") and current_track < TRACK_POSITIONS.size() - 1:
		current_track += 1

	# Calculate the target X position based on the current track.
	var target_x = TRACK_POSITIONS[current_track]
	
	# Smoothly move towards the target X position.
	global_transform.origin.x = lerp(global_transform.origin.x, target_x, MOVE_SPEED * delta)

	# Move the character.
	move_and_slide()

func _on_hitbox_area_entered(area):
	if area.is_in_group("obstacle"):
		lose.emit()
		self.process_mode = Node.PROCESS_MODE_DISABLED
