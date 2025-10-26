extends Control

@onready var hud = $MarginContainer/HUD
@onready var loseUi = $MarginContainer/LoseUI
@onready var startUi = $MarginContainer/StartUI
@onready var colorLabel = hud.get_node("ColorContainer/Color")
@onready var pointsLabel = hud.get_node("ScoreContainer/ValueLabel")
@onready var modifierLabel = hud.get_node("ScoreContainer/ModifierLabel")
@onready var losePointsLabel = loseUi.get_node("ResultsContainer/ScoreContainer/Number")
@onready var loseDistanceLabel = loseUi.get_node("ResultsContainer/DistanceContainer/Number")
@onready var player = get_parent().get_parent().get_node("Player")

var points = 0
var distance = 0

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

func update_points(target: float, point_modifier: float):
	points = target
	pointsLabel.text = str(int(points))
	losePointsLabel.text = str(int(points))
	loseDistanceLabel.text = str(distance*15)
	if point_modifier > 1.0:
		modifierLabel.visible = true
		modifierLabel.text = str(int(point_modifier))
	else:
		modifierLabel.visible = false
		
	
func update_color(target: String, target_color):
	colorLabel.text = target
#	match target_color:
#		"green":
#			colorLabel.set("theme_override_colors/font_color", [red, blue, purple, yellow, orange].pick_random())
#		"red":
#			colorLabel.set("theme_override_colors/font_color", [green, blue, purple, yellow, orange].pick_random())
#		"blue":
#			colorLabel.set("theme_override_colors/font_color", [green, red, purple, yellow, orange].pick_random())
#		"purple":
#			colorLabel.set("theme_override_colors/font_color", [green, red, blue, yellow, orange].pick_random())
#		"yellow":
#			colorLabel.set("theme_override_colors/font_color", [green, red, blue, purple, orange].pick_random())
#		"orange":
#			colorLabel.set("theme_override_colors/font_color", [green, red, blue, purple, yellow].pick_random())


func _on_player_lose():
	is_lost = true
	hud.visible = false
	loseUi.visible = true

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
