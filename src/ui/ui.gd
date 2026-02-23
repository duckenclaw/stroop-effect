extends Control

@onready var hud = $MarginContainer/HUD
@onready var loseUi = $MarginContainer/LoseUI
@onready var startUi = $MarginContainer/StartUI
@onready var colorLabel = hud.get_node("ColorContainer/Color")
@onready var pointsLabel = hud.get_node("RunStatsContainer/ScoreContainer/ValueLabel")
@onready var modifierLabel = hud.get_node("RunStatsContainer/ScoreContainer/ModifierLabel")
@onready var distanceLabel = hud.get_node("RunStatsContainer/DistanceContainer/ValueLabel")
@onready var losePointsLabel = loseUi.get_node("ResultsContainer/ScoreContainer/Number")
@onready var loseDistanceLabel = loseUi.get_node("ResultsContainer/DistanceContainer/Number")
@onready var modifiersContainer = hud.get_node("ModifiersContainer")
@onready var player = get_parent().get_parent().get_node("Player")
@onready var terrain_controller = get_parent().get_parent().get_node("TerrainController")
@onready var camera = get_parent().get_parent().get_node("Camera")

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
	player.double_jump_started.connect(_on_double_jump_started)
	player.double_jump_ended.connect(_on_double_jump_ended)
	player.flight_started.connect(_on_flight_started)
	player.flight_ended.connect(_on_flight_ended)
	startUi.game_start_requested.connect(_on_game_start)

func _process(delta):
	if game_started and not is_lost:
		update_distance()
		_update_modifier_timers(delta)

func update_points(target: float, point_modifier: float):
	points = target
	pointsLabel.text = str(int(points))
	losePointsLabel.text = str(int(points))
	if point_modifier > 1.0:
		modifierLabel.visible = true
		modifierLabel.text = str(int(point_modifier))
	else:
		modifierLabel.visible = false

func update_distance():
	if terrain_controller:
		var distance = terrain_controller.distance
		distanceLabel.text = str(int(distance))
		loseDistanceLabel.text = str(int(distance))
		
	
func update_color(target: String):
	colorLabel.text = target


func _on_player_lose():
	is_lost = true
	hud.visible = false
	loseUi.visible = true

func _on_player_pause():
	hud.visible = false
	loseUi.visible = true

func _on_player_unpause():
	loseUi.visible = false
	hud.visible = true

func _unhandled_input(event):
	# Handle restart key when game is lost
	if event is InputEventKey and event.keycode == 82 and is_lost:
		restart()

func _on_lose_ui_restart():
	restart()

func restart():
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


func _on_lose_ui_exit():
	get_tree().quit(0)

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

func _on_double_jump_started(duration: float):
	_add_modifier_status("Double Jump", duration)

func _on_double_jump_ended():
	_remove_modifier_status("Double Jump")

func _on_flight_started(duration: float):
	_add_modifier_status("Flight", duration)

func _on_flight_ended():
	_remove_modifier_status("Flight")

func _update_modifier_timers(delta: float):
	for modifier_name in active_modifiers.keys():
		var modifier_data = active_modifiers[modifier_name]
		modifier_data.time_left -= delta

		# Update time label (show with 1 decimal place)
		modifier_data.time_label.text = "%.1f" % max(0.0, modifier_data.time_left)

		# Update progress bar (0-100 scale)
		var progress = (modifier_data.time_left / modifier_data.duration) * 100.0
		modifier_data.progress_bar.value = max(0.0, progress)
