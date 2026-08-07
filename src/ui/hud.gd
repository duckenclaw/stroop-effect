class_name Hud
extends Control
## The in-run heads-up display.
##
## Owns its own labels so callers ask for `set_points(...)` rather than reaching through node
## paths like "RunStatsContainer/ScoreContainer/ValueLabel" from outside the scene.

@onready var _color_label: Label = $ColorContainer/Color
@onready var _points_label: Label = $RunStatsContainer/ScoreContainer/ValueLabel
@onready var _modifier_label: Label = $RunStatsContainer/ScoreContainer/ModifierLabel
@onready var _distance_label: Label = $RunStatsContainer/DistanceContainer/ValueLabel
@onready var _modifiers_container: VBoxContainer = $ModifiersContainer

## Last whole-metre value written, so a per-frame distance update does not rebuild an identical
## string 60 times a second.
var _shown_distance := -1

## What the results panel reads when the run ends.
var points_text: String:
	get: return _points_label.text
var distance_text: String:
	get: return _distance_label.text

func set_points(total: float, modifier: float) -> void:
	_points_label.text = str(int(total))
	_modifier_label.visible = modifier > 1.0
	if _modifier_label.visible:
		_modifier_label.text = str(int(modifier))

func set_distance(metres: float) -> void:
	var whole := int(metres)
	if whole == _shown_distance:
		return
	_shown_distance = whole
	_distance_label.text = str(whole)

func set_color_word(color_name: String) -> void:
	_color_label.text = color_name

func add_modifier_chip(chip: Control) -> void:
	_modifiers_container.add_child(chip)
