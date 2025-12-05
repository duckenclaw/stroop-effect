extends Control

@onready var hud = $MarginContainer/HUD
@onready var loseUi = $MarginContainer/LoseUI
@onready var startUi = $MarginContainer/StartUI
@onready var colorLabel = hud.get_node("ColorContainer/Color")
@onready var pointsLabel = hud.get_node("VBoxContainer/ScoreContainer/ValueLabel")
@onready var modifierLabel = hud.get_node("VBoxContainer/ScoreContainer/ModifierLabel")
@onready var distanceLabel = hud.get_node("VBoxContainer/DistanceContainer/ValueLabel")
@onready var losePointsLabel = loseUi.get_node("ResultsContainer/ScoreContainer/Number")
@onready var loseDistanceLabel = loseUi.get_node("ResultsContainer/DistanceContainer/Number")
@onready var player = get_parent().get_parent().get_node("Player")
@onready var terrain_controller = get_parent().get_parent().get_node("TerrainController")

var points = 0.0

var is_lost = false
var game_started = false

var red = Color(0.8, 0, 0, 1.0)
var blue = Color(0.5, 0.5, 1.0, 1.0)
var green = Color(0, 0.8, 0, 1.0)
var purple = Color(0.8, 0, 0.8, 1.0)
var yellow = Color(0.8, 0.8, 0, 1.0)
var orange = Color(0.8, 0.4, 0, 1.0)

func _ready():
	update_points(points, 1.0)
	hud.visible = false
	startUi.visible = true
	player.pause.connect(_on_player_pause)
	player.unpause.connect(_on_player_unpause)

func _process(_delta):
	if game_started and not is_lost:
		update_distance()

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
	# Handle game start on first jump press
	if not game_started and event.is_action_pressed("jump"):
		_on_game_start()
		get_viewport().set_input_as_handled()
	# Handle restart key when game is lost
	elif event is InputEventKey and event.keycode == 82 and is_lost:
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
	player.start_game.emit()


func _on_lose_ui_exit():
	get_tree().quit(0)
