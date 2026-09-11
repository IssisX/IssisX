class_name FoundryEnemy
extends CharacterBody3D

const GeomUtil = preload("res://scripts/geom.gd")

var target: Node3D
var health := 100.0
var speed := 3.7
var attack_cooldown := 0.0
var stagger := 0.0
var held := false
var dead := false

var _visual: Node3D
var _phase := 0.0

func _ready() -> void:
    add_to_group("enemy")
    collision_layer = 4
    collision_mask = 1 | 2 | 8
    GeomUtil.add_capsule_collision(self, 0.42, 1.70)
    _visual = Node3D.new()
    add_child(_visual)
    _build_visual()

func _build_visual() -> void:
    var torso := GeomUtil.box_mesh(
        Vector3(0.74, 0.88, 0.38),
        Color(0.30, 0.33, 0.30)
    )
    torso.position.y = 1.18
    _visual.add_child(torso)
    var head := GeomUtil.sphere_mesh(
        0.25,
        Color(0.56, 0.44, 0.36)
    )
    head.position.y = 1.88
    _visual.add_child(head)
    for side in [-1.0, 1.0]:
        var leg := GeomUtil.box_mesh(
            Vector3(0.23, 0.78, 0.25),
            Color(0.12, 0.13, 0.12)
        )
        leg.position = Vector3(side * 0.20, 0.40, 0.0)
        _visual.add_child(leg)
        var arm := GeomUtil.box_mesh(
            Vector3(0.20, 0.72, 0.22),
            Color(0.27, 0.29, 0.27)
        )
        arm.position = Vector3(side * 0.48, 1.18, 0.0)
        _visual.add_child(arm)

func set_target(node: Node3D) -> void:
    target = node

func take_hit(force: Vector3, damage: float) -> void:
    if dead:
        return
    health -= damage
    stagger = 0.34
    velocity += force
    if health <= 0.0:
        dead = true
        collision_layer = 0
        collision_mask = 1
        velocity += force * 1.8

func set_held(value: bool) -> void:
    held = value
    if held:
        velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
    if held:
        velocity = Vector3.ZERO
        return
    if not is_on_floor():
        velocity.y -= 24.0 * delta
    attack_cooldown = maxf(0.0, attack_cooldown - delta)
    stagger = maxf(0.0, stagger - delta)
    if dead:
        velocity.x *= 0.96
        velocity.z *= 0.96
        move_and_slide()
        return
    if target == null or not is_instance_valid(target):
        move_and_slide()
        return
    var to_target := target.global_position - global_position
    to_target.y = 0.0
    var dist := to_target.length()
    if dist > 1.35 and stagger <= 0.0:
        var dir := to_target.normalized()
        velocity.x = dir.x * speed
        velocity.z = dir.z * speed
        rotation.y = lerp_angle(
            rotation.y,
            atan2(-dir.x, -dir.z),
            0.16
        )
    else:
        velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
        if dist <= 1.55 and attack_cooldown <= 0.0:
            attack_cooldown = 1.05
            if target.has_method("receive_enemy_hit"):
                target.receive_enemy_hit(14.0)
    move_and_slide()
    _animate(delta)

func _animate(delta: float) -> void:
    var planar := Vector2(velocity.x, velocity.z).length()
    _phase += delta * planar * 2.4
    if _visual == null:
        return
    _visual.rotation.z = sin(_phase) * 0.025 * minf(planar, 1.0)
