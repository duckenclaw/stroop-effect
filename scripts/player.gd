extends CharacterBody3D

const JUMP_VELOCITY = 5.5
const TRACK_POSITIONS = [-2.0, 0.0, 2.0]  # Left, Center, Right tracks along the X-axis
const DOWN_SPEED = 50.0 # Speed of going down when pressing down in a jump
const MOVE_SPEED = 7.5 # Speed of lerping between tracks

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var current_track = 1  # Start at the center track (0 = left, 1 = center, 2 = right)

@onready var ui = get_parent().get_node("CanvasLayer/UI")
@onready var audio_stream_player: AudioStreamPlayer3D = $AudioStreamPlayer3D


@export var point_sfx: AudioStreamMP3
@export var color_change_sfx: AudioStreamMP3

@export_dir var materials_path = "res://materials/obstacle_materials/"  # Path to obstacle materials

var colors = []
var current_color = ""
var new_current_color = ""
var pseudo_color = ""
var new_pseudo_color = ""
var points = 0

signal lose()

func _ready():
	_load_colors(materials_path)
	change_color()

func change_color():
	while new_current_color == current_color or new_current_color == "":
		new_current_color = colors.pick_random()
	while new_pseudo_color == new_current_color or new_pseudo_color == pseudo_color:
		new_pseudo_color = colors.pick_random()
	current_color = new_current_color
	pseudo_color = new_pseudo_color
	ui.update_color(current_color, pseudo_color)

func _physics_process(delta):
	# Add gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta
		if Input.is_action_just_pressed("ui_down"):
			velocity.y -= gravity * DOWN_SPEED * delta

	# Handle jump.
	if (Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("jump")) and is_on_floor():
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
	
	# Keep the player centered on the Z axis.
	global_transform.origin.z = lerp(global_transform.origin.z, 0.0, MOVE_SPEED * delta)

	# Move the character.
	move_and_slide()

func _on_hitbox_area_entered(area):
	if area.is_in_group("obstacle"):
		var obstacle_color = area.get_parent().get_node("Mesh").get_active_material(0).get_path().get_file().get_basename()
		if obstacle_color != current_color:
			lose.emit()
			self.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			audio_stream_player.stream = point_sfx
			audio_stream_player.playing = true
			area.get_parent().queue_free()
			add_points(1)
	elif area.is_in_group("collectible"):
		audio_stream_player.stream = color_change_sfx
		audio_stream_player.playing = true
		change_color()
		add_points(3)
		area.queue_free()
			
func add_points(amount: int):
	points += amount
	ui.update_points(points)
	#if points % 3 == 0:
		#change_color()

func _load_colors(target_path: String) -> void:
	var dir = DirAccess.open(target_path)
	for material_path in dir.get_files():
		var material = load(target_path + "/" + material_path)
		if material is Material:
			# Extract the name of the material without the file extension
			var color_name = material_path.get_file().get_basename()  # This removes the extension
			colors.append(color_name)
