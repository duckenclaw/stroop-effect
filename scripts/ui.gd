extends Control

@onready var gUi = $MarginContainer/HUD
@onready var loseUi = $MarginContainer/LoseUI

var is_lost = false

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
