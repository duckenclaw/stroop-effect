extends CharacterBody3D

const JUMP_VELOCITY := 5.5
const TRACK_POSITIONS := [-2.0, 0.0, 2.0]  # Left, Center, Right tracks along the X-axis
const DOWN_SPEED := 100.0 # Speed of going down when pressing down in a jump
const MOVE_SPEED := 7.5 # Speed of lerping between tracks
const STREAK_DECAY := 1.5 # time in second for the streak to decay
const MAX_STREAK := 5.0
const DOUBLE_JUMP_DURATION := 5.0
const FLIGHT_DURATION := 10.0
const COLOR_CLEAR_WIDTH := 7.0
const COLOR_CLEAR_LENGTH := 30.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_slamming: bool = false
var is_on_streak: bool = true
var can_double_jump: bool = false
var is_flying: bool = false
var is_levitating: bool = false
var point_modifier: float = 1.0
@export var modifier_multipier: float = 1.0
var current_track = 1  # Start at the center track (0 = left, 1 = center, 2 = right)
var is_paused: bool = false

@onready var ui = get_parent().get_node("CanvasLayer/UI")
@onready var audio_stream_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var mesh: MeshInstance3D = $Mesh
@onready var slam_raycast: RayCast3D = $SlamRaycast
@onready var streak_timer: Timer = $StreakTimer

var double_jump_timer: Timer
var flight_timer: Timer

@export var point_sfx: AudioStreamMP3
@export var color_change_sfx: AudioStreamMP3

@export_dir var materials_path = "res://assets/resources/materials/outline-materials/"  # Path to obstacle materials

var colors = []
var current_color = ""
var points = 0.0

signal lose()
signal start_game()
signal pause()
signal unpause()
signal match_color(color_name: String)
signal color_clear(color_name: String)
signal double_jump_started(duration: float)
signal double_jump_ended()
signal flight_started(duration: float)
signal flight_ended()

func _ready():
	_load_colors(materials_path)
	change_color(colors.pick_random())
	set_physics_process(false)  # Disable player processing until game starts

	# Create and configure timers
	double_jump_timer = Timer.new()
	double_jump_timer.one_shot = true
	double_jump_timer.timeout.connect(_on_double_jump_timeout)
	add_child(double_jump_timer)

	flight_timer = Timer.new()
	flight_timer.one_shot = true
	flight_timer.timeout.connect(_on_flight_timeout)
	add_child(flight_timer)

func change_color(target_color: String):
	current_color = target_color

	# Load and apply the material to the player mesh
	var material_file = materials_path + "/" + target_color + ".tres"
	var material = load(material_file)

	mesh.material_override = material

	ui.update_color(current_color)

func _physics_process(delta):
	
	if is_levitating:
		global_transform.origin.y = lerp(global_transform.origin.y, 1.5, MOVE_SPEED * delta)
	elif not is_on_floor():
		# Add gravity. 
		velocity.y -= gravity * delta
	if Input.is_action_just_pressed("slam") and !is_slamming and not is_on_floor():
		is_slamming = true
		is_levitating = false
		velocity.y -= gravity * DOWN_SPEED * delta

	# Handle jump.
	if is_on_floor():
		if is_slamming:
			animation_player.play("slam")
			var slammed_object = slam_raycast.get_collider()
			is_slamming = false
			if slammed_object and slammed_object.is_in_group("obstacle"):
				var obstacle_color = slammed_object.get_parent().get_node("Mesh").get_active_material(0).get_path().get_file().get_basename()
				if obstacle_color != current_color:
					animation_player.play("jump", 0.1)
				else:
					audio_stream_player.stream = point_sfx
					audio_stream_player.playing = true
		
					var obstacle = slammed_object.get_parent()
					var collision_point = global_position # Approximation: player’s position
					obstacle.start_dissolve(collision_point)
					velocity.y = JUMP_VELOCITY * 1.5
		
					add_points(2.0)
				
		if Input.is_action_just_pressed("jump"):
			animation_player.play("jump")
			if is_flying:
				is_levitating = true
			else:
				velocity.y = JUMP_VELOCITY
	elif can_double_jump and Input.is_action_just_pressed("jump"):
		animation_player.play("jump")
		velocity.y = JUMP_VELOCITY
	
	# Handle track switching with input.
	if Input.is_action_just_pressed("left") and current_track > 0:
		current_track -= 1
		animation_player.play("left", 0.01)
	elif Input.is_action_just_pressed("right") and current_track < TRACK_POSITIONS.size() - 1:
		current_track += 1
		animation_player.play("right", 0.01)

	# Calculate the target X position based on the current track.
	var target_x = TRACK_POSITIONS[current_track]
	
	# Smoothly move towards the target X position.
	global_transform.origin.x = lerp(global_transform.origin.x, target_x, MOVE_SPEED * delta)
	
	# Keep the player centered on the Z axis.
	global_transform.origin.z = lerp(global_transform.origin.z, 0.0, MOVE_SPEED * delta)

	# Move the character.
	move_and_slide()

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		if is_paused:
			# Unpause the game
			is_paused = false
			unpause.emit()
			set_physics_process(true)
		else:
			# Pause the game
			is_paused = true
			pause.emit()
			set_physics_process(false)
		get_viewport().set_input_as_handled()

func _on_hitbox_area_entered(area):
	
	if area.is_in_group("obstacle"):
		var obstacle_color = area.get_parent().get_node("Mesh").get_active_material(0).get_path().get_file().get_basename()
		if obstacle_color != current_color:
			lose.emit()
			set_physics_process(false)
		else:
			audio_stream_player.stream = point_sfx
			audio_stream_player.playing = true

			var obstacle = area.get_parent()
			var collision_point = global_position # Approximation: player’s position
			obstacle.start_dissolve(collision_point)

			add_points(1.0)

	elif area.is_in_group("color-change"):
		audio_stream_player.stream = color_change_sfx
		audio_stream_player.playing = true
		var collectible_color = area.get_node("Mesh").get_active_material(0).get_path().get_file().get_basename()
		change_color(collectible_color)

		if point_modifier < 5.0:
			point_modifier += modifier_multipier
		else:
			point_modifier = 5.0

		add_points(1.0)
		area.queue_free()

	elif area.is_in_group("color-match"):
		audio_stream_player.stream = color_change_sfx
		audio_stream_player.playing = true
		match_color.emit(current_color)
		add_points(1.0)
		area.queue_free()

	elif area.is_in_group("double-jump"):
		audio_stream_player.stream = color_change_sfx
		audio_stream_player.playing = true
		can_double_jump = true
		double_jump_timer.start(DOUBLE_JUMP_DURATION)
		double_jump_started.emit(DOUBLE_JUMP_DURATION)
		add_points(1.0)
		area.queue_free()

	elif area.is_in_group("color-clear"):
		audio_stream_player.stream = color_change_sfx
		audio_stream_player.playing = true
		color_clear.emit(current_color)
		add_points(1.0)
		area.queue_free()

	elif area.is_in_group("flight"):
		audio_stream_player.stream = color_change_sfx
		audio_stream_player.playing = true
		is_flying = true
		flight_timer.start(FLIGHT_DURATION)
		flight_started.emit(FLIGHT_DURATION)
		add_points(1.0)
		area.queue_free()



func add_points(amount: float):
	points += amount * point_modifier
	streak_timer.start(STREAK_DECAY)
	ui.update_points(points, point_modifier)
	#if points % 3 == 0:
		#change_color()

func _load_colors(target_path: String) -> void:
	var dir = DirAccess.open(target_path)
	for material_path in dir.get_files():
		var material = load(target_path + "/" + material_path)
		if material is ShaderMaterial:
			# Extract the name of the material without the file extension
			var color_name = material_path.get_file().get_basename()  # This removes the extension
			colors.append(color_name)


func _on_animation_player_animation_finished(anim_name):
	match anim_name:
		"slam":
			is_slamming = false
			animation_player.play("idle", 0.5)
		_:
			animation_player.play("idle", 0.5)


func _on_streak_timeout():
	point_modifier = 1.0
	ui.update_points(points, point_modifier)

func _on_double_jump_timeout():
	can_double_jump = false
	double_jump_ended.emit()

func _on_flight_timeout():
	_end_flight()

func _end_flight():
	is_flying = false
	is_levitating = false
	flight_timer.stop()
	flight_ended.emit()
