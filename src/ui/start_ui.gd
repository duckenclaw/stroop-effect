extends Control

signal game_start_requested

@onready var tutorial_panel: PanelContainer = $TutorialPanel
@onready var menu_container: VBoxContainer = $MenuContainer

func _on_start_button_pressed() -> void:
	# Emit signal to request game start
	game_start_requested.emit()

func _on_how_to_play_button_pressed() -> void:
	# Show tutorial panel, hide menu
	menu_container.visible = false
	tutorial_panel.visible = true

func _on_close_button_pressed() -> void:
	# Hide tutorial panel, show menu
	tutorial_panel.visible = false
	menu_container.visible = true

func _on_options_button_pressed() -> void:
	# Placeholder for options menu - can be implemented later
	pass
