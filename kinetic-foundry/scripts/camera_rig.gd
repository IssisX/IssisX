class_name CameraRig
extends Node3D

var target: Node3D
var yaw := 0.0
var pitch := -0.23
var distance := 9.4
var height := 3.1
var look_sensitivity := 0.0038
var collision_margin := 0.42
var minimum_distance := 2.7
var collision_enabled := true

var _camera: Camera3D

func _ready() -> void:
    _camera = Camera3D.new()
    _camera.current = true
    _camera.fov = 68.0
    _camera.near = 0.12
    add_child(_camera)

func set_target(node: Node3D) -> void:
    target = node

func apply_look(delta: Vector2) -> void:
    yaw -= delta.x * look_sensitivity
    pitch -= delta.y * look_sensitivity
    pitch = clamp(pitch, -0.72, 0.20)

func _process(delta: float) -> void:
    if target == null or not is_instance_valid(target):
        return
    var anchor := target.global_position + Vector3.UP * height
    var basis := Basis(Vector3.UP, yaw)
    var back := basis * Vector3(0.0, 0.0, distance)
    var vertical := Vector3.UP * (-sin(pitch) * distance)
    var desired := anchor + back + vertical
    if collision_enabled and OS.get_environment("KF_CAPTURE") != "1":
        desired = _resolve_camera_collision(anchor, desired)
    var response := 13.0 if global_position.distance_to(desired) > 2.2 else 9.0
    global_position = global_position.lerp(desired, 1.0 - exp(-response * delta))
    _camera.look_at(anchor, Vector3.UP)

func _resolve_camera_collision(anchor: Vector3, desired: Vector3) -> Vector3:
    var ray := desired - anchor
    var ray_len := ray.length()
    if ray_len <= minimum_distance:
        return desired
    var query := PhysicsRayQueryParameters3D.create(anchor, desired, 2 | 8)
    if target != null:
        query.exclude = [target]
    query.collide_with_areas = false
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return desired
    var dir := ray.normalized()
    var safe_len := maxf(minimum_distance, anchor.distance_to(hit.position) - collision_margin)
    return anchor + dir * safe_len

func flat_forward() -> Vector3:
    var forward := -_camera.global_basis.z
    forward.y = 0.0
    if forward.length_squared() < 0.001:
        return Vector3.FORWARD
    return forward.normalized()

func flat_right() -> Vector3:
    var right := _camera.global_basis.x
    right.y = 0.0
    if right.length_squared() < 0.001:
        return Vector3.RIGHT
    return right.normalized()
