class_name PlayerTrail
extends MeshInstance3D
## The speed streak that follows the player.
##
## Rebuilt from scratch every physics frame as a camera-facing ribbon through a short history of
## world-space points. The node is top_level (set in player.tscn) so it does not inherit the
## player's transform -- the points it draws are already in world space.

const ALPHA := 0.45  # a plain half-transparent streak, not additive
const POINT_COUNT := 28  # ~0.45s of history at 60Hz physics
const WIDTH := 0.22  # half-width at the head; tapers to 0 at the tail
const HEIGHT := 0.5  # anchored at the player mesh's centre, not its feet

## The node the streak trails behind -- the player, whose transform this node deliberately ignores.
@onready var _target: Node3D = get_parent()

var _material: StandardMaterial3D
var _mesh: ImmediateMesh
var _points: Array[Vector3] = []
var _camera: Camera3D

func _ready() -> void:
	# Own the material so set_color() tints this trail rather than the shared sub-resource baked
	# into player.tscn.
	_material = material_override.duplicate()
	material_override = _material
	_mesh = ImmediateMesh.new()
	mesh = _mesh
	global_transform = Transform3D.IDENTITY

func set_tint(vivid: Color) -> void:
	_material.albedo_color = Color(vivid.r, vivid.g, vivid.b, ALPHA)

## Records one frame of history and redraws. Pumped by the player rather than run from this node's
## own _physics_process, so the trail stays frozen until the player's physics is enabled.
func advance(delta: float) -> void:
	# The player barely translates in world space -- the terrain scrolls past it instead. So
	# recorded points are pushed backwards at the scroll speed, which is what turns the history
	# into a streak trailing the player rather than a dot sitting under it.
	var drift := Game.scroll_speed() * delta
	for i in _points.size():
		var point := _points[i]
		point.z += drift
		_points[i] = point
	_points.push_front(_target.global_position + Vector3(0, HEIGHT, 0))
	if _points.size() > POINT_COUNT:
		_points.resize(POINT_COUNT)
	_rebuild()

func _rebuild() -> void:
	_mesh.clear_surfaces()
	if _points.size() < 2:
		return
	# Face the ribbon at the camera so it stays visible however the path curves.
	var camera_position := _camera_position()
	var last := _points.size() - 1

	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in _points.size():
		var head_to_tail := float(i) / float(last)  # 0 at the player, 1 at the tail
		var point := _points[i]
		var tangent := _points[maxi(i - 1, 0)] - _points[mini(i + 1, last)]
		if tangent.length_squared() < 0.000001:
			tangent = Vector3.FORWARD
		var to_camera := camera_position - point
		var side := tangent.normalized().cross(to_camera.normalized())
		if side.length_squared() < 0.000001:
			side = Vector3.RIGHT
		# Narrow to a point and fade out toward the tail.
		side = side.normalized() * WIDTH * (1.0 - head_to_tail)
		var fade := Color(1, 1, 1, 1.0 - head_to_tail)
		_mesh.surface_set_color(fade)
		_mesh.surface_add_vertex(point + side)
		_mesh.surface_set_color(fade)
		_mesh.surface_add_vertex(point - side)
	_mesh.surface_end()

## Cached rather than looked up per frame; re-resolved if the camera is ever replaced.
func _camera_position() -> Vector3:
	if not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
	if _camera:
		return _camera.global_position
	return _target.global_position + Vector3(0, 4, 4)
