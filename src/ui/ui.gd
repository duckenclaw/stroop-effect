extends Control

@onready var hud = $MarginContainer/HUD
@onready var loseUi = $MarginContainer/LoseUI
@onready var startUi = $MarginContainer/StartUI
@onready var pauseUi = $MarginContainer/PauseUI
@onready var colorLabel = hud.get_node("ColorContainer/Color")
@onready var pointsLabel = hud.get_node("RunStatsContainer/ScoreContainer/ValueLabel")
@onready var modifierLabel = hud.get_node("RunStatsContainer/ScoreContainer/ModifierLabel")
@onready var distanceLabel = hud.get_node("RunStatsContainer/DistanceContainer/ValueLabel")
@onready var losePointsLabel = loseUi.get_node("ResultsContainer/ScoreContainer/Number")
@onready var loseDistanceLabel = loseUi.get_node("ResultsContainer/DistanceContainer/Number")
@onready var modifiersContainer = hud.get_node("ModifiersContainer")
@onready var player = Game.player
@onready var terrain_controller = Game.terrain
@onready var camera = Game.camera

# Preloaded modifier status scene
var modifier_status_scene = preload("res://src/ui/modifier_status.tscn")

# Active modifier tracking
var active_modifiers = {}  # Dictionary to track active modifiers: {name: {node, duration, time_left}}

var points = 0.0

var is_lost = false
var game_started = false

func _ready():
	update_points(points, 1.0)
	hud.visible = false
	startUi.visible = true
	player.pause.connect(_on_player_pause)
	player.unpause.connect(_on_player_unpause)
	player.points_changed.connect(update_points)
	player.color_changed.connect(update_color)
	player.effect_started.connect(_add_modifier_status)
	player.effect_ended.connect(_remove_modifier_status)
	player.collision_with_obstacle.connect(camera._on_collision_shake)
	player.slam_ended.connect(camera._on_slam_shake)
	startUi.game_start_requested.connect(_on_game_start)

func _process(delta):
	# This node runs with process_mode = ALWAYS so its buttons stay clickable while the tree is
	# paused, which means the pause check has to be explicit here.
	if game_started and not is_lost and not get_tree().paused:
		update_distance()
		_update_modifier_timers(delta)

func update_points(target: float, point_modifier: float):
	points = target
	pointsLabel.text = str(int(points))
	modifierLabel.visible = point_modifier > 1.0
	if modifierLabel.visible:
		modifierLabel.text = str(int(point_modifier))

func update_distance():
	if terrain_controller:
		distanceLabel.text = str(int(terrain_controller.distance))


func update_color(target: String):
	colorLabel.text = target

## The results panel is only ever read once the run stops, so it is filled in at that moment
## rather than written every frame while hidden.
func _snapshot_results():
	losePointsLabel.text = pointsLabel.text
	loseDistanceLabel.text = distanceLabel.text

func _on_player_lose():
	is_lost = true
	hud.visible = false
	_snapshot_results()
	loseUi.visible = true

func _on_player_pause():
	hud.visible = false
	pauseUi.visible = true

func _on_player_unpause():
	pauseUi.visible = false
	hud.visible = true

func _on_pause_ui_resume():
	player.set_paused(false)

func _unhandled_input(event):
	# Handle restart key when game is lost. Physical keycode so it stays on the same physical key
	# regardless of layout.
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_R and is_lost:
		restart()
		return
	# Pause lives here rather than on the player: pausing the tree stops the player from
	# receiving input, so it could never unpause itself.
	if event.is_action_pressed("ui_cancel") and game_started and not is_lost:
		player.set_paused(not player.is_paused)
		get_viewport().set_input_as_handled()

func _on_restart_requested():
	restart()

func restart():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_game_start():
	game_started = true
	startUi.visible = false
	hud.visible = true

	# Enable player physics processing
	player.set_physics_process(true)

	# Start the game (emit signal to terrain controller)
	# Terrain begins immediately as camera transitions
	player.start_game.emit()

	# Trigger smooth camera transition to gameplay position
	camera.transition_to_gameplay()


# Modifier status functions
func _add_modifier_status(modifier_name: String, duration: float):
	# If modifier already exists, update it
	if active_modifiers.has(modifier_name):
		active_modifiers[modifier_name].duration = duration
		active_modifiers[modifier_name].time_left = duration
		return

	# Create new modifier status display
	var modifier_status = modifier_status_scene.instantiate()
	modifiersContainer.add_child(modifier_status)

	# Get references to the child nodes
	var effect_label = modifier_status.get_node("EffectLabel")
	var time_label = modifier_status.get_node("TimeProgress/TimeLabel")
	var progress_bar = modifier_status.get_node("TimeProgress/TextureProgressBar")

	# Set the effect name
	effect_label.text = modifier_name

	# Store in active modifiers dictionary
	active_modifiers[modifier_name] = {
		"node": modifier_status,
		"duration": duration,
		"time_left": duration,
		"effect_label": effect_label,
		"time_label": time_label,
		"progress_bar": progress_bar
	}

func _remove_modifier_status(modifier_name: String):
	if active_modifiers.has(modifier_name):
		var modifier_data = active_modifiers[modifier_name]
		modifier_data.node.queue_free()
		active_modifiers.erase(modifier_name)

func _update_modifier_timers(delta: float):
	for modifier_name in active_modifiers.keys():
		var modifier_data = active_modifiers[modifier_name]
		modifier_data.time_left -= delta

		# Update time label (show with 1 decimal place)
		modifier_data.time_label.text = "%.1f" % max(0.0, modifier_data.time_left)

		# Update progress bar (0-100 scale)
		var progress = (modifier_data.time_left / modifier_data.duration) * 100.0
		modifier_data.progress_bar.value = max(0.0, progress)
