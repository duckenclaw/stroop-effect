extends Control

signal game_start_requested

@onready var tutorial_panel: PanelContainer = $MarginContainer/TutorialPanel
@onready var menu_container: VBoxContainer = $MarginContainer/MenuContainer
@onready var options_panel: PanelContainer = $MarginContainer/OptionsPanel
@onready var master_slider: HSlider = $MarginContainer/OptionsPanel/MarginContainer/VBoxContainer/MasterSlider
@onready var music_slider: HSlider = $MarginContainer/OptionsPanel/MarginContainer/VBoxContainer/MusicSlider
@onready var sfx_slider: HSlider = $MarginContainer/OptionsPanel/MarginContainer/VBoxContainer/SFXSlider

func _ready() -> void:
	# Initialize sliders with current audio bus volumes (converted from db to 0-100 range)
	master_slider.value = _db_to_slider(AudioServer.get_bus_volume_db(0))
	music_slider.value = _db_to_slider(AudioServer.get_bus_volume_db(1))
	sfx_slider.value = _db_to_slider(AudioServer.get_bus_volume_db(2))

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
	# Show options panel, hide menu
	menu_container.visible = false
	options_panel.visible = true

func _on_options_back_pressed() -> void:
	# Hide options panel, show menu
	options_panel.visible = false
	menu_container.visible = true

func _on_master_volume_changed(value: float) -> void:
	var volume_linear = value / 100.0  # Convert 0-100 to 0-1
	AudioServer.set_bus_volume_db(0, linear_to_db(volume_linear))

func _on_music_volume_changed(value: float) -> void:
	var volume_linear = value / 100.0  # Convert 0-100 to 0-1
	AudioServer.set_bus_volume_db(1, linear_to_db(volume_linear))

func _on_sfx_volume_changed(value: float) -> void:
	var volume_linear = value / 100.0  # Convert 0-100 to 0-1
	AudioServer.set_bus_volume_db(2, linear_to_db(volume_linear))

func _db_to_slider(db: float) -> float:
	# Convert decibels to 0-100 slider range
	var linear = db_to_linear(db)
	return linear * 100.0
