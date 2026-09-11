class_name PhysicsProp
extends RigidBody3D

const GeomUtil = preload("res://scripts/geom.gd")
const ImpactFx = preload("res://scripts/impact_fx.gd")

var health := 80.0
var destroyed := false
var impact_scale := 1.0
var held := false
var impact_color := Color(0.72, 0.45, 0.12)

func _ready() -> void:
    add_to_group("physics_prop")
    collision_layer = 8
    collision_mask = 1 | 2 | 4 | 8
    sleeping = true
    can_sleep = true

func configure_box(
        size: Vector3,
        color: Color,
        mass_value: float = 75.0,
        hp: float = 80.0
) -> void:
    mass = mass_value
    health = hp
    impact_color = color.lightened(0.32)
    add_child(GeomUtil.box_mesh(size, color, 0.86, 0.16))
    GeomUtil.add_box_collision(self, size)

func configure_barrel(
        radius: float,
        height: float,
        color: Color,
        mass_value: float = 48.0,
        hp: float = 58.0
) -> void:
    mass = mass_value
    health = hp
    impact_color = color.lightened(0.38)
    add_child(GeomUtil.cylinder_mesh(radius, height, color, 0.76, 0.22))
    GeomUtil.add_cylinder_collision(self, radius, height)
    for y in [-height * 0.32, height * 0.32]:
        var ring := GeomUtil.cylinder_mesh(
            radius * 1.045,
            0.06,
            Color(0.075, 0.08, 0.075),
            0.72,
            0.28
        )
        ring.position.y = y
        add_child(ring)

func set_held(value: bool) -> void:
    held = value
    sleeping = false
    freeze = value
    if value:
        linear_velocity = Vector3.ZERO
        angular_velocity = Vector3.ZERO

func machine_hit(amount: float, direction: Vector3) -> void:
    _receive_impact(amount * 1.35, direction, 14.0)

func take_hit(force: Vector3, damage: float) -> void:
    if held:
        set_held(false)
    var dir := force
    if dir.length_squared() < 0.001:
        dir = Vector3.UP
    _receive_impact(damage, dir.normalized(), force.length())

func _receive_impact(
        damage: float,
        direction: Vector3,
        impulse_strength: float
) -> void:
    if destroyed:
        return
    sleeping = false
    health -= damage
    var impulse := direction.normalized() * maxf(impulse_strength, damage * 0.22)
    impulse += Vector3.UP * minf(damage * 0.055, 4.2)
    apply_central_impulse(impulse * mass * 0.18 * impact_scale)
    apply_torque_impulse(
        Vector3(direction.z, 0.35, -direction.x) * damage * mass * 0.025
    )
    ImpactFx.spawn(
        get_parent(),
        global_position + Vector3.UP * 0.45,
        direction,
        impact_color,
        clampf(damage / 20.0, 0.7, 3.5),
        7
    )
    if health <= 0.0:
        destroyed = true
        linear_damp = 0.18
        angular_damp = 0.12
        apply_central_impulse(direction.normalized() * mass * 4.5)
        ImpactFx.spawn(
            get_parent(),
            global_position + Vector3.UP * 0.35,
            direction,
            impact_color,
            3.4,
            13
        )
