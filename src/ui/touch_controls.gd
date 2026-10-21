class_name TouchControls
extends Node
## Turns swipes and taps into the same input actions the keyboard drives.
##
## The player polls Input.is_action_just_pressed(), so rather than teaching it a second input
## path this presses the action for a couple of physics frames and lets the keyboard code handle
## it. Swipe left/right changes lane, up jumps, down slams, and a plain tap also jumps.

## Minimum travel, as a fraction of the screen's shorter side, for a touch to count as a swipe.
const SWIPE_THRESHOLD := 0.06
## A touch held longer than this without travelling far enough is ignored rather than read as a tap.
const TAP_MAX_TIME := 0.3
## Physics frames an injected action stays down. The press has to survive the physics_frame
## signal, which fires before _physics_process in the same step, so one frame is not enough.
const HOLD_FRAMES := 2

## Touches that start on these are left to the control, so tapping pause does not also jump.
var exclusion_zones: Array[Control] = []

## Where and when the current gesture started, or empty between gestures. Only the first finger
## (index 0) gestures, so a second finger resting on the screen does not fire extra actions.
var _start: Dictionary = {}

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)

func _on_touch(event: InputEventScreenTouch) -> void:
	if event.index != 0:
		return
	if event.pressed:
		_start = {}
		if _gameplay_active() and not _in_exclusion_zone(event.position):
			_start = {"position": event.position, "time": _now(), "fired": false}
		return
	var start := _start
	_start = {}
	if start.is_empty() or start.fired:
		return
	if _now() - start.time <= TAP_MAX_TIME:
		_trigger(&"jump")

## Swipes fire as soon as they pass the threshold rather than on release, which matters in a
## runner -- waiting for the finger to lift adds a noticeable delay to every lane change.
func _on_drag(event: InputEventScreenDrag) -> void:
	if event.index != 0 or _start.is_empty() or _start.fired:
		return
	var travel: Vector2 = event.position - _start.position
	var viewport_size := get_viewport().get_visible_rect().size
	if travel.length() < SWIPE_THRESHOLD * minf(viewport_size.x, viewport_size.y):
		return
	_start.fired = true
	if absf(travel.x) > absf(travel.y):
		_trigger(&"right" if travel.x > 0.0 else &"left")
	else:
		_trigger(&"slam" if travel.y > 0.0 else &"jump")

func _trigger(action: StringName) -> void:
	Input.action_press(action)
	for i in HOLD_FRAMES:
		await get_tree().physics_frame
	Input.action_release(action)

## Menus are driven by tapping their buttons, so gestures only mean anything during a run.
func _gameplay_active() -> bool:
	var player := Game.player
	return player != null and player.is_physics_processing() and not get_tree().paused

func _in_exclusion_zone(point: Vector2) -> bool:
	for zone in exclusion_zones:
		if zone.is_visible_in_tree() and zone.get_global_rect().has_point(point):
			return true
	return false

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
