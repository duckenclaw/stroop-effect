class_name Obstacle
extends StaticBody3D

const DISSOLVE_MATERIAL: ShaderMaterial = preload("res://assets/resources/materials/dissolve_material.tres")
const DISSOLVE_SPEED := 6.5
const START_RADIUS := 0.001
const BORDER_RADIUS := 10.0

@onready var mesh: MeshInstance3D = $Mesh
@onready var top_collider: CollisionShape3D = $Collider
@onready var hitbox_collider: CollisionShape3D = $Hitbox/Collider

## Which color this obstacle currently is. Assigned by TerrainController at spawn and whenever
## a color-match effect repaints it; the player compares against this rather than re-deriving
## the name from the material's resource path on every collision.
var color_name := ""

# Own copy of the dissolve material, created on demand. The preloaded resource is shared by every
# obstacle, so writing sphere_radius/sphere_position straight to it would make simultaneous
# dissolves (which color-clear triggers by design) fight over one set of parameters.
var _dissolve_material: ShaderMaterial
var _radius := START_RADIUS

func _ready() -> void:
	# Nothing to advance until start_dissolve() is called, and there are dozens of live obstacles.
	set_process(false)

## Callers must have added this obstacle to the tree first, so @onready mesh is resolved.
func set_color(new_color: String) -> void:
	color_name = new_color
	mesh.material_override = ColorUtil.material_for(new_color)

func start_dissolve(collision_point: Vector3) -> void:
	if _dissolve_material:
		return  # already dissolving
	hitbox_collider.queue_free()
	top_collider.queue_free()
	_dissolve_material = DISSOLVE_MATERIAL.duplicate()
	_radius = START_RADIUS
	_dissolve_material.set("shader_parameter/sphere_radius", _radius)
	_dissolve_material.set("shader_parameter/sphere_position", collision_point)
	mesh.material_override = _dissolve_material
	set_process(true)

func _process(delta: float) -> void:
	_radius += DISSOLVE_SPEED * delta
	_dissolve_material.set("shader_parameter/sphere_radius", _radius)
	if _radius > BORDER_RADIUS:
		queue_free()
