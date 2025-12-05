extends StaticBody3D

@onready var mesh: MeshInstance3D = $Mesh
@onready var top_collider: CollisionShape3D = $Collider
@onready var hitbox: Area3D = $Hitbox
@onready var hitbox_collider: CollisionShape3D = $Hitbox/Collider
@onready var dissolve_shader: ShaderMaterial = load("res://assets/resources/materials/dissolve_material.tres")

var dissolving := false
var dissolve_speed := 4.5
var start_radius := 0.001
var border_radius := 10.0
var dissolve_center := Vector3.ZERO

func start_dissolve(collision_point: Vector3):
	hitbox_collider.queue_free()
	top_collider.queue_free()
	dissolve_center = collision_point
	dissolve_shader.set("shader_parameter/sphere_radius", start_radius)
	dissolve_shader.set("shader_parameter/sphere_position", dissolve_center)
	mesh.set_material_override(dissolve_shader)
	dissolving = true

func _process(delta: float) -> void:
	if dissolving:
		var radius: float = dissolve_shader.get("shader_parameter/sphere_radius")
		radius += dissolve_speed * delta
		dissolve_shader.set("shader_parameter/sphere_radius", radius)

		if radius > border_radius:
			queue_free()