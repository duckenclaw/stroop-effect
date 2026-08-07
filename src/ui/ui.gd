extends Control
## Screen switching and run state. Everything it displays is owned by a child scene -- see hud.gd,
## lose_ui.gd and modifier_status.gd -- so this file routes rather than formats.

const MODIFIER_STATUS_SCENE := preload("res://src/ui/modifier_status.tscn")

@onready var hud: Hud = $MarginContainer/HUD
@onready var lose_ui: LoseUI = $MarginContainer/LoseUI
@onready var start_ui: Control = $MarginContainer/StartUI
@onready var pause_ui: Control = $MarginContainer/PauseUI
@onready var player: Player = Game.player
@onready var terrain_controller: TerrainController = Game.terrain

## Raised when the player presses Start. world.tscn routes it to the Player and the Camera.
signal game_started

var is_lost := false
var is_started := false

## TimedEffect -> its on-screen chip, so re-activating a running effect does not stack a second
## one. The chips free themselves when their effect expires.
var _chips: Dictionary = {}

func _ready():
	hud.set_points(0.0, 1.0)
	hud.visible = false
	start_ui.visible = true

func _process(_delta):
	# This node runs with process_mode = ALWAYS so its buttons stay clickable while the tree is
	# paused, which means the pause check has to be explicit here.
	if is_started and not is_lost and not get_tree().paused:
		hud.set_distance(terrain_controller.distance)

func _unhandled_input(event):
	# Handle restart key when game is lost. Physical keycode so it stays on the same physical key
	# regardless of layout.
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_R and is_lost:
		restart()
		return
	# Pause lives here rather than on the player: pausing the tree stops the player from
	# receiving input, so it could never unpause itself.
	if event.is_action_pressed("ui_cancel") and is_started and not is_lost:
		player.set_paused(not player.is_paused)
		get_viewport().set_input_as_handled()

func restart():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_start_ui_game_start_requested():
	is_started = true
	start_ui.visible = false
	hud.visible = true
	# world.tscn routes this to the player (which enables its own physics and announces
	# start_game) and to the camera's transition. Terrain begins as the camera moves.
	game_started.emit()

func _on_restart_requested():
	restart()

func _on_pause_ui_resume():
	player.set_paused(false)

func _on_player_points_changed(total: float, modifier: float):
	hud.set_points(total, modifier)

func _on_player_color_changed(color_name: String):
	hud.set_color_word(color_name)

func _on_player_lose():
	is_lost = true
	hud.visible = false
	lose_ui.show_results(hud.points_text, hud.distance_text)

func _on_player_pause():
	hud.visible = false
	pause_ui.visible = true

func _on_player_unpause():
	pause_ui.visible = false
	hud.visible = true

func _on_player_effect_started(effect: TimedEffect):
	if _chips.has(effect):
		return  # re-activating just extends the timer the existing chip already reads
	var chip: ModifierStatus = MODIFIER_STATUS_SCENE.instantiate()
	hud.add_modifier_chip(chip)
	chip.bind(effect)
	_chips[effect] = chip

func _on_player_effect_ended(effect: TimedEffect):
	_chips.erase(effect)  # the chip removes itself; this just frees the slot for a re-activation
