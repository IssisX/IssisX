class_name FoundryPlayer
extends CharacterBody3D

const GeomUtil = preload("res://scripts/geom.gd")

signal request_machine_entry(player)

var hud
var camera_rig
var health := 180.0
var speed := 7.4
var sprint_speed := 10.2
var engaged_target
var engage_timer := 0.0
var held_target
var attack_cooldown := 0.0
var _visual: Node3D
var _phase := 0.0

func _ready() -> void:
    add_to_group("player")
    collision_layer = 1
    collision_mask = 1 | 2 | 4 | 8
    GeomUtil.add_capsule_collision(self, 0.46, 1.82)
    _visual = Node3D.new()
    add_child(_visual)
    _build_visual()

func configure(controls, camera) -> void:
    hud = controls
    camera_rig = camera

func receive_enemy_hit(damage: float) -> void:
    health = maxf(0.0, health - damage)

func _build_visual() -> void:
    var torso := GeomUtil.box_mesh(
        Vector3(0.86, 1.02, 0.48),
        Color(0.20, 0.23, 0.22),
        0.72,
        0.08
    )
    torso.position.y = 1.24
    _visual.add_child(torso)
    var head := GeomUtil.sphere_mesh(
        0.27,
        Color(0.64, 0.48, 0.37)
    )
    head.position.y = 2.00
    _visual.add_child(head)
    for side in [-1.0, 1.0]:
        var arm := GeomUtil.box_mesh(
            Vector3(0.25, 0.84, 0.27),
            Color(0.25, 0.28, 0.26)
        )
        arm.name = "Arm"
        arm.position = Vector3(side * 0.56, 1.28, 0.0)
        _visual.add_child(arm)
        var leg := GeomUtil.box_mesh(
            Vector3(0.29, 0.88, 0.30),
            Color(0.10, 0.11, 0.10)
        )
        leg.name = "Leg"
        leg.position = Vector3(side * 0.23, 0.44, 0.0)
        _visual.add_child(leg)

func _physics_process(delta: float) -> void:
    if hud == null or camera_rig == null:
        return
    attack_cooldown = maxf(0.0, attack_cooldown - delta)
    engage_timer = maxf(0.0, engage_timer - delta)
    if engage_timer <= 0.0 and held_target == null:
        engaged_target = null
    var axis: Vector2 = hud.move_axis + _keyboard_axis()
    if axis.length() > 1.0:
        axis = axis.normalized()
    var forward: Vector3 = camera_rig.flat_forward()
    var right: Vector3 = camera_rig.flat_right()
    var desired: Vector3 = right * axis.x + forward * -axis.y
    var target_speed: float = speed
    if axis.length() > 0.94:
        target_speed = sprint_speed
    if desired.length_squared() > 0.001:
        desired = desired.normalized()
        velocity.x = move_toward(
            velocity.x,
            desired.x * target_speed,
            32.0 * delta
        )
        velocity.z = move_toward(
            velocity.z,
            desired.z * target_speed,
            32.0 * delta
        )
        rotation.y = lerp_angle(
            rotation.y,
            atan2(-desired.x, -desired.z),
            0.22
        )
    else:
        velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
    if not is_on_floor():
        velocity.y -= 26.0 * delta
    var look: Vector2 = hud.consume_look()
    camera_rig.apply_look(look)
    if hud.consume_attack() or _keyboard_attack():
        _attack()
    if hud.consume_grab() or _keyboard_grab():
        _grab_or_throw()
    if hud.consume_use() or _keyboard_use():
        request_machine_entry.emit(self)
    if held_target != null and is_instance_valid(held_target):
        _update_held_target()
    move_and_slide()
    _animate(delta)

func _keyboard_axis() -> Vector2:
    var axis := Vector2.ZERO
    if Input.is_physical_key_pressed(KEY_A):
        axis.x -= 1.0
    if Input.is_physical_key_pressed(KEY_D):
        axis.x += 1.0
    if Input.is_physical_key_pressed(KEY_W):
        axis.y -= 1.0
    if Input.is_physical_key_pressed(KEY_S):
        axis.y += 1.0
    return axis

func _keyboard_attack() -> bool:
    return Input.is_physical_key_pressed(KEY_J)

func _keyboard_grab() -> bool:
    return Input.is_physical_key_pressed(KEY_K)

func _keyboard_use() -> bool:
    return Input.is_physical_key_pressed(KEY_E)

func _attack() -> void:
    if attack_cooldown > 0.0:
        return
    attack_cooldown = 0.34
    if held_target != null and is_instance_valid(held_target):
        var throw_dir: Vector3 = -global_basis.z
        held_target.set_held(false)
        held_target.take_hit(
            throw_dir * 15.0 + Vector3.UP * 5.8,
            34.0
        )
        held_target = null
        return
    var target = _find_target(2.25)
    if target == null:
        return
    engaged_target = target
    engage_timer = 1.0
    var dir: Vector3 = target.global_position - global_position
    dir.y = 0.0
    if dir.length_squared() < 0.01:
        dir = -global_basis.z
    target.take_hit(
        dir.normalized() * 7.6 + Vector3.UP * 1.9,
        26.0
    )

func _grab_or_throw() -> void:
    if held_target != null and is_instance_valid(held_target):
        var dir: Vector3 = -global_basis.z
        held_target.set_held(false)
        held_target.take_hit(
            dir * 12.5 + Vector3.UP * 4.7,
            22.0
        )
        held_target = null
        return
    var target = _find_target(1.75)
    if target == null:
        return
    held_target = target
    engaged_target = target
    engage_timer = 2.0
    target.set_held(true)

func _update_held_target() -> void:
    var hold_pos: Vector3 = (
        global_position
        - global_basis.z * 1.05
        + Vector3.UP * 1.15
    )
    held_target.global_position = held_target.global_position.lerp(
        hold_pos,
        0.48
    )
    held_target.rotation.y = rotation.y

func _find_target(radius: float):
    if engaged_target != null and is_instance_valid(engaged_target):
        var d: float = global_position.distance_to(engaged_target.global_position)
        if d <= radius * 1.25:
            return engaged_target
    var best = null
    var best_score: float = -9999.0
    var forward: Vector3 = -global_basis.z
    for enemy in get_tree().get_nodes_in_group("enemy"):
        if not enemy.visible:
            continue
        if enemy.dead:
            continue
        var offset: Vector3 = enemy.global_position - global_position
        var dist: float = offset.length()
        if dist > radius:
            continue
        var dir: Vector3 = offset.normalized()
        var facing: float = forward.dot(dir)
        var score: float = facing * 2.0 - dist * 0.55
        if score > best_score:
            best_score = score
            best = enemy
    return best

func _animate(delta: float) -> void:
    var planar := Vector2(velocity.x, velocity.z).length()
    _phase += delta * planar * 2.25
    if _visual == null:
        return
    var swing := sin(_phase) * 0.44 * minf(planar / speed, 1.0)
    var arm_i := 0
    var leg_i := 0
    for child in _visual.get_children():
        if child.name == "Arm":
            child.rotation.x = swing if arm_i == 0 else -swing
            arm_i += 1
        elif child.name == "Leg":
            child.rotation.x = -swing if leg_i == 0 else swing
            leg_i += 1
