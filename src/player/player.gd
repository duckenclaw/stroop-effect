extends CharacterBody3D

const JUMP_VELOCITY := 5.5
const SLAM_BOUNCE_MULTIPLIER := 1.5  # applied to JUMP_VELOCITY when a slam destroys an obstacle
const TRACK_POSITIONS := [-2.0, 0.0, 2.0]  # Left, Center, Right tracks along the X-axis
const DOWN_SPEED := 100.0 # Speed of going down when pressing down in a jump
const MOVE_SPEED := 7.5 # Speed of lerping between tracks
const STREAK_DECAY := 3.5 # time in second for the streak to decay
const MAX_STREAK := 5.0
const DOUBLE_JUMP_DURATION := 5.0
const FLIGHT_DURATION := 10.0
const FLIGHT_HEIGHT := 2.0

const PUFF_WHITE_MIX := 0.2  # small white core; the rest stays the player's hue
const PUFF_ALPHA := 0.55  # multiplied by the color_ramp alpha envelope
const PUFF_GAIN := 1.6  # pushes the tint past 1.0 so the additive blend reads as a glow
const TRAIL_ALPHA := 0.45  # the trail is a plain half-transparent streak, not additive
const TRAIL_POINTS := 28  # ~0.45s of history at 60Hz physics
const TRAIL_WIDTH := 0.22  # half-width at the head; tapers to 0 at the tail
const TRAIL_HEIGHT := 0.5  # anchored at the player mesh's centre, not its feet
const FALLBACK_SCROLL_SPEED := 5.5  # used only if TerrainController isn't reachable

# One emitter serves every event; these presets are applied just before restart(). "dir" always
# points away from the direction of travel. "vel" and "scale" are (min, max) pairs. "drift" makes
# a puff travel with the scrolling ground instead of hanging still in world space.
const PUFF_PRESETS := {
	"lane_left": {
		"dir": Vector3(1, 0.25, 0), "y": 0.35, "amount": 10, "spread": 35.0, "life": 0.4,
		"vel": Vector2(2.0, 3.5), "grav": Vector3(0, -3, 0), "drift": true, "scale": Vector2(0.6, 1.2),
		"radius": 0.25,
	},
	"lane_right": {
		"dir": Vector3(-1, 0.25, 0), "y": 0.35, "amount": 10, "spread": 35.0, "life": 0.4,
		"vel": Vector2(2.0, 3.5), "grav": Vector3(0, -3, 0), "drift": true, "scale": Vector2(0.6, 1.2),
		"radius": 0.25,
	},
	"jump": {
		"dir": Vector3(0, -1, 0), "y": 0.25, "amount": 14, "spread": 60.0, "life": 0.4,
		"vel": Vector2(1.2, 2.2), "grav": Vector3(0, 4, 0), "drift": true, "scale": Vector2(0.5, 1.0),
		"radius": 0.3,
	},
	"slam_start": {
		"dir": Vector3(0, 1, 0), "y": 0.5, "amount": 8, "spread": 40.0, "life": 0.35,
		"vel": Vector2(2.0, 3.0), "grav": Vector3(0, -6, 0), "drift": false, "scale": Vector2(0.4, 0.8),
		"radius": 0.25,
	},
	"slam_land": {
		"dir": Vector3(0, 1, 0), "y": 0.1, "amount": 26, "spread": 75.0, "life": 0.55,
		"vel": Vector2(3.0, 5.0), "grav": Vector3(0, -8, 0), "drift": true, "scale": Vector2(0.8, 1.6),
		"radius": 0.35,
	},
}

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_slamming: bool = false
var is_levitating: bool = false  # currently hovering; flight.active means the power-up is held
var point_modifier: float = 1.0
@export var modifier_multipier: float = 1.0
var current_track = 1  # Start at the center track (0 = left, 1 = center, 2 = right)
var is_paused: bool = false

@onready var audio_stream_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var mesh: MeshInstance3D = $Mesh
@onready var slam_raycast: RayCast3D = $SlamRaycast
@onready var streak_timer: Timer = $StreakTimer
@onready var puff_particles: CPUParticles3D = $PuffParticles
@onready var trail: MeshInstance3D = $Trail

var puff_tint: Color = Color(1, 1, 1, PUFF_ALPHA)
var trail_material: StandardMaterial3D
var trail_mesh: ImmediateMesh
var trail_points: Array[Vector3] = []

var double_jump: TimedEffect
var flight: TimedEffect

# Group -> handler for everything the player can pick up. Adding a collectible type means adding
# an entry and a one-line handler rather than another branch in an if/elif chain.
var _pickup_handlers: Dictionary = {}

@export var point_sfx: AudioStreamMP3
@export var color_change_sfx: AudioStreamMP3

var current_color = ""
var points = 0.0

signal lose()
signal start_game()
signal pause()
signal unpause()
signal match_color(color_name: String)
signal color_clear(color_name: String)
signal effect_started(effect_name: String, duration: float)
signal effect_ended(effect_name: String)
signal collision_with_obstacle()
signal slam_ended()
signal points_changed(total: float, modifier: float)
signal color_changed(color_name: String)

func _ready():
	# Own the trail material so change_color() tints this player rather than the shared
	# sub-resource baked into player.tscn. Must happen before the first change_color() call.
	trail_material = trail.material_override.duplicate()
	trail.material_override = trail_material
	# The trail is rebuilt every physics frame from world-space points, so the node must not
	# inherit the player's transform (top_level is set in player.tscn).
	trail_mesh = ImmediateMesh.new()
	trail.mesh = trail_mesh
	trail.global_transform = Transform3D.IDENTITY
	change_color(ColorUtil.random_name())
	set_physics_process(false)  # Disable player processing until game starts

	double_jump = TimedEffect.attach(self, "Double Jump")
	flight = TimedEffect.attach(self, "Flight")
	for effect in [double_jump, flight]:
		effect.activated.connect(_on_effect_activated)
		effect.expired.connect(_on_effect_expired)
	flight.expired.connect(_on_flight_expired)

	_pickup_handlers = {
		&"color-change": _pickup_color_change,
		&"color-match": _pickup_color_match,
		&"double-jump": _pickup_double_jump,
		&"color-clear": _pickup_color_clear,
		&"flight": _pickup_flight,
	}

func change_color(target_color: String):
	current_color = target_color

	var vivid := ColorUtil.vivid(current_color)
	puff_tint = vivid.lerp(Color.WHITE, PUFF_WHITE_MIX) * PUFF_GAIN
	puff_tint.a = PUFF_ALPHA
	if trail_material:
		trail_material.albedo_color = Color(vivid.r, vivid.g, vivid.b, TRAIL_ALPHA)

	mesh.material_override = ColorUtil.material_for(current_color)

	color_changed.emit(current_color)

func _physics_process(delta):
	
	if is_levitating:
		global_transform.origin.y = lerp(global_transform.origin.y, FLIGHT_HEIGHT, MOVE_SPEED * delta)
	elif not is_on_floor():
		# Add gravity. 
		velocity.y -= gravity * delta
	if Input.is_action_just_pressed("slam") and !is_slamming and not is_on_floor():
		is_slamming = true
		is_levitating = false
		velocity.y -= gravity * DOWN_SPEED * delta
		_emit_puff("slam_start")

	# Handle jump.
	if is_on_floor():
		if is_slamming:
			animation_player.play("slam")
			_emit_puff("slam_land")
			# The raycast collides with areas only, so the hit is an obstacle's Hitbox, not its body.
			var slammed_hitbox = slam_raycast.get_collider()
			is_slamming = false
			slam_ended.emit()
			var slammed_obstacle: Obstacle = null
			if slammed_hitbox:
				slammed_obstacle = slammed_hitbox.get_parent() as Obstacle
			if slammed_obstacle:
				if slammed_obstacle.color_name != current_color:
					animation_player.play("jump", 0.1)
				else:
					_destroy_obstacle(slammed_obstacle, true)

		if Input.is_action_just_pressed("jump"):
			animation_player.play("jump")
			_emit_puff("jump")
			if flight.active:
				is_levitating = true
			else:
				velocity.y = JUMP_VELOCITY
	elif double_jump.active and Input.is_action_just_pressed("jump"):
		animation_player.play("jump")
		_emit_puff("jump")
		velocity.y = JUMP_VELOCITY
	
	# Handle track switching with input.
	if Input.is_action_just_pressed("left") and current_track > 0:
		current_track -= 1
		animation_player.play("left", 0.01)
		_emit_puff("lane_left")
	elif Input.is_action_just_pressed("right") and current_track < TRACK_POSITIONS.size() - 1:
		current_track += 1
		animation_player.play("right", 0.01)
		_emit_puff("lane_right")

	# Calculate the target X position based on the current track.
	var target_x = TRACK_POSITIONS[current_track]
	
	# Smoothly move towards the target X position.
	global_transform.origin.x = lerp(global_transform.origin.x, target_x, MOVE_SPEED * delta)
	
	# Keep the player centered on the Z axis.
	global_transform.origin.z = lerp(global_transform.origin.z, 0.0, MOVE_SPEED * delta)

	# Move the character.
	move_and_slide()

	_update_trail(delta)

func _scroll_speed() -> float:
	var terrain := Game.terrain
	if terrain:
		return terrain.get_scroll_speed()
	return FALLBACK_SCROLL_SPEED

func _update_trail(delta: float) -> void:
	# The player barely translates in world space -- the terrain scrolls past it instead. So
	# recorded points are pushed backwards at the scroll speed, which is what turns the history
	# into a streak trailing the player rather than a dot sitting under it.
	var scroll := _scroll_speed()
	var drift := scroll * delta
	for i in trail_points.size():
		var point := trail_points[i]
		point.z += drift
		trail_points[i] = point
	trail_points.push_front(global_position + Vector3(0, TRAIL_HEIGHT, 0))
	if trail_points.size() > TRAIL_POINTS:
		trail_points.resize(TRAIL_POINTS)
	_rebuild_trail()

func _rebuild_trail() -> void:
	trail_mesh.clear_surfaces()
	if trail_points.size() < 2:
		return
	# Face the ribbon at the camera so it stays visible however the path curves.
	var camera := get_viewport().get_camera_3d()
	var camera_position := camera.global_position if camera else global_position + Vector3(0, 4, 4)
	var last := trail_points.size() - 1

	trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in trail_points.size():
		var head_to_tail := float(i) / float(last)  # 0 at the player, 1 at the tail
		var point := trail_points[i]
		var tangent := trail_points[maxi(i - 1, 0)] - trail_points[mini(i + 1, last)]
		if tangent.length_squared() < 0.000001:
			tangent = Vector3.FORWARD
		var to_camera := camera_position - point
		var side := tangent.normalized().cross(to_camera.normalized())
		if side.length_squared() < 0.000001:
			side = Vector3.RIGHT
		# Narrow to a point and fade out toward the tail.
		side = side.normalized() * TRAIL_WIDTH * (1.0 - head_to_tail)
		trail_mesh.surface_set_color(Color(1, 1, 1, 1.0 - head_to_tail))
		trail_mesh.surface_add_vertex(point + side)
		trail_mesh.surface_set_color(Color(1, 1, 1, 1.0 - head_to_tail))
		trail_mesh.surface_add_vertex(point - side)
	trail_mesh.surface_end()

func _emit_puff(preset_name: String) -> void:
	var cfg: Dictionary = PUFF_PRESETS.get(preset_name, {})
	if cfg.is_empty():
		push_warning("Unknown puff preset: " + preset_name)
		return
	# One emitter serves every event, so the whole shape is reapplied each time. Anything set
	# here is picked up by restart() below; local_coords stays false so the burst is emitted at
	# the player's current global position and then left behind in the world.
	puff_particles.position.y = cfg["y"]
	puff_particles.direction = cfg["dir"]
	puff_particles.amount = cfg["amount"]
	puff_particles.spread = cfg["spread"]
	puff_particles.lifetime = cfg["life"]
	var grav: Vector3 = cfg["grav"]
	if cfg["drift"]:
		grav.z = _scroll_speed()  # travel with the ground rather than racing ahead of it
	puff_particles.gravity = grav
	puff_particles.emission_sphere_radius = cfg["radius"]
	puff_particles.initial_velocity_min = cfg["vel"].x
	puff_particles.initial_velocity_max = cfg["vel"].y
	puff_particles.scale_amount_min = cfg["scale"].x
	puff_particles.scale_amount_max = cfg["scale"].y
	puff_particles.color = puff_tint
	# restart() clears live particles, reseeds and re-enables emitting, so it correctly
	# re-fires a finished one_shot. Setting emitting = true as well is not needed.
	puff_particles.restart()

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
		_on_obstacle_hit(area.get_parent() as Obstacle)
		return
	for group in _pickup_handlers:
		if area.is_in_group(group):
			_collect(area, _pickup_handlers[group])
			return

func _on_obstacle_hit(obstacle: Obstacle) -> void:
	collision_with_obstacle.emit()
	if obstacle.color_name != current_color:
		lose.emit()
		set_physics_process(false)
	else:
		_destroy_obstacle(obstacle, false)

## Shared by the frontal-collision and the slam-from-above paths.
func _destroy_obstacle(obstacle: Obstacle, bounce: bool) -> void:
	_play_sfx(point_sfx)
	obstacle.start_dissolve(global_position)
	if bounce:
		velocity.y = JUMP_VELOCITY * SLAM_BOUNCE_MULTIPLIER
	add_points(1.0)

## Every collectible sounds the same, scores the same and frees itself; only the effect differs.
func _collect(area: Area3D, effect: Callable) -> void:
	_play_sfx(color_change_sfx)
	effect.call(area)
	add_points(1.0)
	area.queue_free()

func _play_sfx(stream: AudioStream) -> void:
	audio_stream_player.stream = stream
	audio_stream_player.playing = true

func _pickup_color_change(area: Area3D) -> void:
	# Collectibles are scriptless Area3Ds, so the name still comes off the material here.
	change_color(ColorUtil.name_of(area.get_node("Mesh").get_active_material(0)))
	if point_modifier < MAX_STREAK:
		point_modifier += modifier_multipier
	else:
		point_modifier = MAX_STREAK

func _pickup_color_match(_area: Area3D) -> void:
	match_color.emit(current_color)

func _pickup_color_clear(_area: Area3D) -> void:
	color_clear.emit(current_color)

func _pickup_double_jump(_area: Area3D) -> void:
	double_jump.activate(DOUBLE_JUMP_DURATION)

func _pickup_flight(_area: Area3D) -> void:
	flight.activate(FLIGHT_DURATION)

func add_points(amount: float):
	points += amount * point_modifier
	streak_timer.start(STREAK_DECAY)
	points_changed.emit(points, point_modifier)

func _on_animation_player_animation_finished(anim_name):
	match anim_name:
		"slam":
			is_slamming = false
			animation_player.play("idle", 0.5)
		_:
			animation_player.play("idle", 0.5)


func _on_streak_timeout():
	point_modifier = 1.0
	points_changed.emit(points, point_modifier)

func _on_effect_activated(effect_name: String, duration: float) -> void:
	effect_started.emit(effect_name, duration)

func _on_effect_expired(effect_name: String) -> void:
	effect_ended.emit(effect_name)

func _on_flight_expired(_effect_name: String) -> void:
	is_levitating = false
