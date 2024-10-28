extends Control

@onready var gUi = $MarginContainer/HUD
@onready var loseUi = $MarginContainer/LoseUI


func _on_player_lose():
	gUi.visible = false
	loseUi.visible = true


func _on_lose_ui_restart():
	get_tree().reload_current_scene()
