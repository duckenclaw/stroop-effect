class_name TimedEffect
extends Timer
## A named, self-expiring power-up.
##
## Bundles the timer, the display name and the start/end notifications that every timed pickup
## needs, so adding one is a single attach() call rather than another timer plus another pair of
## signals on the player and another pair of handlers on the UI.

signal activated(effect_name: String, duration: float)
signal expired(effect_name: String)

var effect_name := ""

## True while the effect is running.
var active: bool:
	get: return not is_stopped()

static func attach(host: Node, display_name: String) -> TimedEffect:
	var effect := TimedEffect.new()
	effect.effect_name = display_name
	effect.one_shot = true
	host.add_child(effect)
	effect.timeout.connect(effect._on_timeout)
	return effect

func activate(duration: float) -> void:
	start(duration)
	activated.emit(effect_name, duration)

## Ends the effect early. Does nothing if it wasn't running, so callers don't have to check.
func cancel() -> void:
	if is_stopped():
		return
	stop()
	expired.emit(effect_name)

func _on_timeout() -> void:
	expired.emit(effect_name)
