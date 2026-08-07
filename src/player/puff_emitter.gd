class_name PuffEmitter
extends CPUParticles3D
## The wind puffs the player kicks up on lane changes, jumps and slams.
##
## One emitter serves every event: the preset is applied to this node just before restart(), so
## adding a new burst means adding a PRESETS entry rather than another particle node.

const WHITE_MIX := 0.2  # small white core; the rest stays the player's hue
const ALPHA := 0.55  # multiplied by the color_ramp alpha envelope
const GAIN := 1.6  # pushes the tint past 1.0 so the additive blend reads as a glow

# "dir" always points away from the direction of travel. "vel" and "scale" are (min, max) pairs.
# "drift" makes a puff travel with the scrolling ground instead of hanging still in world space.
const PRESETS := {
	&"lane_left": {
		"dir": Vector3(1, 0.25, 0), "y": 0.35, "amount": 10, "spread": 35.0, "life": 0.4,
		"vel": Vector2(2.0, 3.5), "grav": Vector3(0, -3, 0), "drift": true, "scale": Vector2(0.6, 1.2),
		"radius": 0.25,
	},
	&"lane_right": {
		"dir": Vector3(-1, 0.25, 0), "y": 0.35, "amount": 10, "spread": 35.0, "life": 0.4,
		"vel": Vector2(2.0, 3.5), "grav": Vector3(0, -3, 0), "drift": true, "scale": Vector2(0.6, 1.2),
		"radius": 0.25,
	},
	&"jump": {
		"dir": Vector3(0, -1, 0), "y": 0.25, "amount": 14, "spread": 60.0, "life": 0.4,
		"vel": Vector2(1.2, 2.2), "grav": Vector3(0, 4, 0), "drift": true, "scale": Vector2(0.5, 1.0),
		"radius": 0.3,
	},
	&"slam_start": {
		"dir": Vector3(0, 1, 0), "y": 0.5, "amount": 8, "spread": 40.0, "life": 0.35,
		"vel": Vector2(2.0, 3.0), "grav": Vector3(0, -6, 0), "drift": false, "scale": Vector2(0.4, 0.8),
		"radius": 0.25,
	},
	&"slam_land": {
		"dir": Vector3(0, 1, 0), "y": 0.1, "amount": 26, "spread": 75.0, "life": 0.55,
		"vel": Vector2(3.0, 5.0), "grav": Vector3(0, -8, 0), "drift": true, "scale": Vector2(0.8, 1.6),
		"radius": 0.35,
	},
}

var _tint: Color = Color(1, 1, 1, ALPHA)

## Named set_tint rather than set_color because CPUParticles3D already has a native set_color()
## backing its `color` property, which this would silently shadow.
func set_tint(vivid: Color) -> void:
	_tint = vivid.lerp(Color.WHITE, WHITE_MIX) * GAIN
	_tint.a = ALPHA

func emit_preset(preset_name: StringName) -> void:
	var cfg: Dictionary = PRESETS.get(preset_name, {})
	if cfg.is_empty():
		push_warning("Unknown puff preset: " + preset_name)
		return
	# The whole shape is reapplied each time, since one emitter serves every event. local_coords
	# stays false so the burst is emitted at the player's current global position and then left
	# behind in the world.
	position.y = cfg["y"]
	direction = cfg["dir"]
	amount = cfg["amount"]
	spread = cfg["spread"]
	lifetime = cfg["life"]
	var grav: Vector3 = cfg["grav"]
	if cfg["drift"]:
		grav.z = Game.scroll_speed()  # travel with the ground rather than racing ahead of it
	gravity = grav
	emission_sphere_radius = cfg["radius"]
	initial_velocity_min = cfg["vel"].x
	initial_velocity_max = cfg["vel"].y
	scale_amount_min = cfg["scale"].x
	scale_amount_max = cfg["scale"].y
	color = _tint
	# restart() clears live particles, reseeds and re-enables emitting, so it correctly re-fires a
	# finished one_shot. Setting emitting = true as well is not needed.
	restart()
