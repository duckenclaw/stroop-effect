class_name LoseUI
extends Control

signal restart()

@onready var _points_label: Label = $ResultsContainer/ScoreContainer/Number
@onready var _distance_label: Label = $ResultsContainer/DistanceContainer/Number

## Fills in the results and reveals the panel. Called once when the run stops, rather than writing
## these labels every frame while they are hidden.
func show_results(points: String, distance: String) -> void:
	_points_label.text = points
	_distance_label.text = distance
	visible = true

func _on_restart_button_pressed():
	restart.emit()
