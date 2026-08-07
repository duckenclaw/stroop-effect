class_name ModifierStatus
extends Control
## One power-up chip in the HUD: name, remaining seconds, and a draining bar.
##
## Reads the TimedEffect's own Timer rather than counting down a copy of the duration, so the bar
## cannot drift from the effect it describes. The Timer lives under the player (PAUSABLE) while
## this node runs with process_mode ALWAYS, which is why the display freezes on pause by itself.

@onready var _effect_label: Label = $EffectLabel
@onready var _time_label: Label = $TimeProgress/TimeLabel
@onready var _progress_bar: TextureProgressBar = $TimeProgress/TextureProgressBar

var _effect: TimedEffect

func bind(effect: TimedEffect) -> void:
	_effect = effect
	_effect_label.text = effect.effect_name
	effect.expired.connect(_on_effect_expired)
	_refresh()

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	if _effect == null:
		return
	_time_label.text = "%.1f" % _effect.time_left
	_progress_bar.value = _effect.time_left / maxf(_effect.wait_time, 0.001) * 100.0

func _on_effect_expired(_expired_effect: TimedEffect) -> void:
	queue_free()
