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
    var pelvis := GeomUtil.box_mesh(
        Vector3(0.64, 0.32, 0.38),
        Color(0.105, 0.11, 0.105),
        0.88,
        0.02
    )
    pelvis.position.y = 0.84
    _visual.add_child(pelvis)

    var torso := GeomUtil.box_mesh(
        Vector3(0.76, 0.84, 0.42),
        Color(0.25, 0.285, 0.26),
        0.78,
        0.03
    )
    torso.position.y = 1.31
    _visual.add_child(torso)

    var chest_mark := GeomUtil.box_mesh(
        Vector3(0.64, 0.16, 0.06),
        Color(0.66, 0.46, 0.08),
        0.72,
        0.04
    )
    chest_mark.position = Vector3(0.0, 1.43, -0.24)
    _visual.add_child(chest_mark)

    var head := GeomUtil.sphere_mesh(
        0.245,
        Color(0.54, 0.41, 0.33)
    )
    head.position.y = 1.93
    _visual.add_child(head)

    var hardhat := GeomUtil.box_mesh(
        Vector3(0.52, 0.16, 0.52),
        Color(0.74, 0.54, 0.10),
        0.76,
        0.04
    )
    hardhat.position = Vector3(0.0, 2.09, 0.0)
    _visual.add_child(hardhat)

    for side in [-1.0, 1.0]:
        var arm := GeomUtil.capsule_mesh(
            0.115,
            0.72,
            Color(0.22, 0.25, 0.23)
        )
        arm.name = "Arm"
        arm.position = Vector3(side * 0.47, 1.20, 0.0)
        _visual.add_child(arm)

        var glove := GeomUtil.sphere_mesh(
            0.13,
            Color(0.065, 0.07, 0.065)
        )
        glove.position = Vector3(side * 0.47, 0.82, 0.0)
        _visual.add_child(glove)

        var leg := GeomUtil.capsule_mesh(
            0.145,
            0.82,
            Color(0.09, 0.095, 0.09)
        )
        leg.name = "Leg"
        leg.position = Vector3(side * 0.19, 0.44, 0.0)
        _visual.add_child(leg)

        var boot := GeomUtil.box_mesh(
            Vector3(0.27, 0.18, 0.43),
            Color(0.05, 0.055, 0.05),
            0.97,
            0.02
        )
        boot.position = Vector3(side * 0.19, 0.09, -0.06)
        _visual.add_child(boot)

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
    var swing := sin(_phase) * 0.32 * minf(planar / speed, 1.0)
    var arm_i := 0
    var leg_i := 0
    for child in _visual.get_children():
        if child.name == "Arm":
            child.rotation.x = swing if arm_i == 0 else -swing
            arm_i += 1
        elif child.name == "Leg":
            child.rotation.x = -swing if leg_i == 0 else swing
            leg_i += 1
    _visual.rotation.z = sin(_phase) * 0.012 * minf(planar, 1.0)
