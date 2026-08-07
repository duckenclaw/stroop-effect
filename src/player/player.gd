class_name Player
extends CharacterBody3D
## Locomotion, input and pickup routing.
##
## The player's visual effects and its score live in sibling components on child nodes -- see
## trail.gd, puff_emitter.gd and score_keeper.gd.

const JUMP_VELOCITY := 5.5
const SLAM_BOUNCE_MULTIPLIER := 1.5  # applied to JUMP_VELOCITY when a slam destroys an obstacle
const TRACK_POSITIONS := [-2.0, 0.0, 2.0]  # Left, Center, Right tracks along the X-axis
# Downward kick when slamming. Was gravity * 100.0 * delta, which made the slam twice as strong
# at 30fps as at 60; this is that expression's value at 60fps, applied as a one-off impulse.
const SLAM_IMPULSE := 20.0
const MOVE_SPEED := 7.5 # Rate of exponential smoothing between tracks
const DOUBLE_JUMP_DURATION := 5.0
const FLIGHT_DURATION := 10.0
const FLIGHT_HEIGHT := 2.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_slamming: bool = false
var is_levitating: bool = false  # currently hovering; flight.active means the power-up is held
var air_jump_used: bool = false  # reset on landing, so double jump grants one jump per airtime
var current_track = 1  # Start at the center track (0 = left, 1 = center, 2 = right)
var is_paused: bool = false

@onready var audio_stream_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var mesh: MeshInstance3D = $Mesh
@onready var slam_raycast: RayCast3D = $SlamRaycast
@onready var score: ScoreKeeper = $Score
@onready var puff: PuffEmitter = $PuffParticles
@onready var trail: PlayerTrail = $Trail

var double_jump: TimedEffect
var flight: TimedEffect

# Group -> handler for everything the player can pick up. Adding a collectible type means adding
# an entry and a one-line handler rather than another branch in an if/elif chain.
var _pickup_handlers: Dictionary = {}

@export var point_sfx: AudioStreamMP3
@export var color_change_sfx: AudioStreamMP3

var current_color = ""

## The run's score. Owned by the ScoreKeeper; forwarded because other systems ask the player.
var points: float:
	get: return score.points

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
	change_color(ColorUtil.random_name())
	set_physics_process(false)  # Disable player processing until game starts

	score.changed.connect(points_changed.emit)

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

## The UI owns the start button, but the player owns the decision to start moving.
func _on_game_started() -> void:
	set_physics_process(true)
	start_game.emit()

func change_color(target_color: String):
	current_color = target_color

	var vivid := ColorUtil.vivid(current_color)
	puff.set_tint(vivid)
	trail.set_tint(vivid)
	mesh.material_override = ColorUtil.material_for(current_color)

	color_changed.emit(current_color)

func _physics_process(delta):
	if is_levitating:
		global_transform.origin.y = _smooth(global_transform.origin.y, FLIGHT_HEIGHT, MOVE_SPEED, delta)
	elif not is_on_floor():
		# Add gravity.
		velocity.y -= gravity * delta
	if Input.is_action_just_pressed("slam") and !is_slamming and not is_on_floor():
		is_slamming = true
		is_levitating = false
		velocity.y -= SLAM_IMPULSE
		puff.emit_preset(&"slam_start")

	# Handle jump.
	if is_on_floor():
		air_jump_used = false
		if is_slamming:
			_land_slam()

		if Input.is_action_just_pressed("jump"):
			animation_player.play("jump")
			puff.emit_preset(&"jump")
			if flight.active:
				is_levitating = true
			else:
				velocity.y = JUMP_VELOCITY
	elif double_jump.active and not air_jump_used and Input.is_action_just_pressed("jump"):
		# One extra jump per airborne stretch, refreshed on landing -- not an unlimited supply
		# for the whole duration, which is what an unconsumed flag gave.
		air_jump_used = true
		animation_player.play("jump")
		puff.emit_preset(&"jump")
		velocity.y = JUMP_VELOCITY

	# Handle track switching with input.
	if Input.is_action_just_pressed("left") and current_track > 0:
		current_track -= 1
		animation_player.play("left", 0.01)
		puff.emit_preset(&"lane_left")
	elif Input.is_action_just_pressed("right") and current_track < TRACK_POSITIONS.size() - 1:
		current_track += 1
		animation_player.play("right", 0.01)
		puff.emit_preset(&"lane_right")

	# Smoothly move towards the current track, and keep the player centered on the Z axis.
	global_transform.origin.x = _smooth(global_transform.origin.x, TRACK_POSITIONS[current_track], MOVE_SPEED, delta)
	global_transform.origin.z = _smooth(global_transform.origin.z, 0.0, MOVE_SPEED, delta)

	move_and_slide()

	trail.advance(delta)

func _land_slam() -> void:
	animation_player.play("slam")
	puff.emit_preset(&"slam_land")
	is_slamming = false
	slam_ended.emit()
	# The raycast collides with areas only, so the hit is an obstacle's Hitbox, not its body.
	var slammed_hitbox = slam_raycast.get_collider()
	if slammed_hitbox == null:
		return
	var slammed_obstacle := slammed_hitbox.get_parent() as Obstacle
	if slammed_obstacle == null:
		return
	if slammed_obstacle.color_name != current_color:
		animation_player.play("jump", 0.1)
	else:
		_destroy_obstacle(slammed_obstacle, true)

## Frame-rate independent exponential smoothing. Plain lerp(a, b, rate * delta) converges faster
## the higher the frame rate, so lane changes felt different at 30fps and 144fps.
static func _smooth(from: float, to: float, rate: float, delta: float) -> float:
	return lerp(from, to, 1.0 - exp(-rate * delta))

## Pausing the whole tree freezes physics, the obstacle dissolves and the camera shake together,
## which toggling only this node's physics never did. The UI drives it, because a paused player
## stops receiving input and so could not unpause itself.
func set_paused(value: bool) -> void:
	if is_paused == value:
		return
	is_paused = value
	get_tree().paused = value
	if value:
		pause.emit()
	else:
		unpause.emit()

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
	score.add(1.0)

## Every collectible sounds the same, scores the same and frees itself; only the effect differs.
func _collect(area: Area3D, effect: Callable) -> void:
	_play_sfx(color_change_sfx)
	effect.call(area)
	score.add(1.0)
	area.queue_free()

func _play_sfx(stream: AudioStream) -> void:
	audio_stream_player.stream = stream
	audio_stream_player.playing = true

func _pickup_color_change(area: Area3D) -> void:
	# Collectibles are scriptless Area3Ds, so the name still comes off the material here.
	change_color(ColorUtil.name_of(area.get_node("Mesh").get_active_material(0)))
	score.boost()

func _pickup_color_match(_area: Area3D) -> void:
	match_color.emit(current_color)

func _pickup_color_clear(_area: Area3D) -> void:
	color_clear.emit(current_color)

func _pickup_double_jump(_area: Area3D) -> void:
	double_jump.activate(DOUBLE_JUMP_DURATION)

func _pickup_flight(_area: Area3D) -> void:
	flight.activate(FLIGHT_DURATION)

## Terrain effects such as color-clear score through the player so the streak multiplier applies.
func add_points(amount: float) -> void:
	score.add(amount)

func _on_animation_player_animation_finished(anim_name):
	match anim_name:
		"slam":
			is_slamming = false
			animation_player.play("idle", 0.5)
		_:
			animation_player.play("idle", 0.5)

func _on_effect_activated(effect_name: String, duration: float) -> void:
	effect_started.emit(effect_name, duration)

func _on_effect_expired(effect_name: String) -> void:
	effect_ended.emit(effect_name)

func _on_flight_expired(_effect_name: String) -> void:
	is_levitating = false
