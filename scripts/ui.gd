extends Control

@onready var gUi = $MarginContainer/HUD
@onready var loseUi = $MarginContainer/LoseUI

var points = 0

var is_lost = false

var red = Color(0.7, 0, 0.05, 1.0)
var blue = Color(0, 0.05, 0.7, 1.0)
var green = Color(0.05, 0.7, 0, 1.0)

func _ready():
	update_points(points)

func update_points(target: int):
	points = target
	gUi.get_node("HBoxContainer/Number").text = str(points)
	loseUi.get_node("HBoxContainer/Number").text = str(points)
	
func update_color(target: String, target_color):
	var colorLabel = gUi.get_node("Color")
	colorLabel.text = target
	match target_color:
		"red":
			colorLabel.set("theme_override_colors/font_color", red)
			print("red")
		"blue":
			colorLabel.set("theme_override_colors/font_color", blue)
			print("blue")
		"green":
			colorLabel.set("theme_override_colors/font_color", green)
			print("green")

func _on_player_lose():
	is_lost = true
	gUi.visible = false
	loseUi.visible = true

func _unhandled_key_input(event):
	if event.keycode == 82 and is_lost:
		restart()

func _on_lose_ui_restart():
	restart()

func restart():
	get_tree().reload_current_scene()
