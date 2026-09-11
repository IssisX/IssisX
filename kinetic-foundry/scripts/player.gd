class_name FoundryPlayer
extends CharacterBody3D

const GeomUtil = preload("res://scripts/geom.gd")
const HumanoidRigScript = preload("res://scripts/humanoid_rig.gd")

signal request_machine_entry(player)

var hud
var camera_rig
var health := 180.0
var max_health := 180.0
var speed := 7.4
var sprint_speed := 10.2
var engaged_target
var engage_timer := 0.0
var held_target
var attack_cooldown := 0.0
var attack_anim := 0.0
var hit_anim := 0.0
var combo_window := 0.0
var combo_step := 0
var attack_side := 1.0
var traversal_lock := 0.0
var _rig

func _ready() -> void:
    add_to_group("player")
    collision_layer = 1
    collision_mask = 1 | 2 | 4 | 8
    var collision := GeomUtil.add_capsule_collision(self, 0.46, 1.82)
    collision.position.y = 0.91
    _rig = HumanoidRigScript.new()
    add_child(_rig)
    _rig.configure(true)

func configure(controls, camera) -> void:
    hud = controls
    camera_rig = camera

func receive_enemy_hit(damage: float) -> void:
    health = maxf(0.0, health - damage)
    hit_anim = 0.28
    if hud != null and hud.has_method("flash_damage"):
        hud.flash_damage()

func receive_hazard_hit(damage: float, impulse: Vector3) -> void:
    receive_enemy_hit(damage)
    velocity += impulse

func _physics_process(delta: float) -> void:
    if hud == null or camera_rig == null:
        return
    attack_cooldown = maxf(0.0, attack_cooldown - delta)
    attack_anim = maxf(0.0, attack_anim - delta)
    hit_anim = maxf(0.0, hit_anim - delta)
    combo_window = maxf(0.0, combo_window - delta)
    traversal_lock = maxf(0.0, traversal_lock - delta)
    engage_timer = maxf(0.0, engage_timer - delta)
    if combo_window <= 0.0:
        combo_step = 0
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
    if attack_anim > 0.0:
        target_speed *= 0.42

    if traversal_lock <= 0.0:
        if desired.length_squared() > 0.001:
            desired = desired.normalized()
            velocity.x = move_toward(velocity.x, desired.x * target_speed, 32.0 * delta)
            velocity.z = move_toward(velocity.z, desired.z * target_speed, 32.0 * delta)
            if attack_anim <= 0.0:
                rotation.y = lerp_angle(rotation.y, atan2(-desired.x, -desired.z), 0.22)
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
        if not _try_traversal():
            request_machine_entry.emit(self)

    if held_target != null and is_instance_valid(held_target):
        _update_held_target()

    move_and_slide()
    _animate(delta)
    _update_hud()

func _try_traversal() -> bool:
    if traversal_lock > 0.0 or not is_on_floor() or held_target != null:
        return false
    var space := get_world_3d().direct_space_state
    var forward := -global_basis.z
    var low_from := global_position + Vector3.UP * 0.65
    var low_to := low_from + forward * 1.35
    var low_query := PhysicsRayQueryParameters3D.create(low_from, low_to, 2 | 8)
    low_query.exclude = [self]
    var low_hit := space.intersect_ray(low_query)
    if low_hit.is_empty():
        return false

    var high_from := global_position + Vector3.UP * 1.45
    var high_to := high_from + forward * 1.45
    var high_query := PhysicsRayQueryParameters3D.create(high_from, high_to, 2 | 8)
    high_query.exclude = [self]
    var high_hit := space.intersect_ray(high_query)

    if high_hit.is_empty():
        velocity = forward * 8.8 + Vector3.UP * 6.8
        traversal_lock = 0.34
        if hud != null and hud.has_method("set_context"):
            hud.set_context("VAULT")
        return true

    var chest_from := global_position + Vector3.UP * 1.72
    var chest_to := chest_from + forward * 1.15
    var chest_query := PhysicsRayQueryParameters3D.create(chest_from, chest_to, 2 | 8)
    chest_query.exclude = [self]
    var chest_hit := space.intersect_ray(chest_query)
    if chest_hit.is_empty():
        velocity = forward * 5.2 + Vector3.UP * 8.2
        traversal_lock = 0.44
        if hud != null and hud.has_method("set_context"):
            hud.set_context("MANTLE")
        return true
    return false

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
    if attack_cooldown > 0.0 or traversal_lock > 0.0:
        return
    attack_cooldown = 0.24 if combo_step < 2 else 0.38
    attack_anim = 0.28
    attack_side *= -1.0
    if _rig != null:
        _rig.set_attack_side(attack_side)

    if held_target != null and is_instance_valid(held_target):
        var throw_dir: Vector3 = -global_basis.z
        held_target.set_held(false)
        held_target.take_hit(throw_dir * 17.0 + Vector3.UP * 6.2, 38.0)
        held_target = null
        combo_step = 0
        combo_window = 0.0
        return

    var damage := [24.0, 29.0, 39.0][combo_step]
    var push_strength := [7.4, 8.8, 13.8][combo_step]
    var lift := [1.5, 2.0, 3.9][combo_step]
    var target = _find_target(2.35)
    if target != null:
        engaged_target = target
        engage_timer = 1.15
        var dir: Vector3 = target.global_position - global_position
        dir.y = 0.0
        if dir.length_squared() < 0.01:
            dir = -global_basis.z
        dir = dir.normalized()
        rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 0.62)
        velocity += dir * (1.7 if combo_step < 2 else 2.8)
        target.take_hit(dir * push_strength + Vector3.UP * lift, damage)
        combo_step = (combo_step + 1) % 3
        combo_window = 0.66
        return

    var prop = _find_prop(2.15)
    if prop != null:
        var prop_dir: Vector3 = prop.global_position - global_position
        prop_dir.y = 0.0
        if prop_dir.length_squared() < 0.01:
            prop_dir = -global_basis.z
        prop_dir = prop_dir.normalized()
        prop.take_hit(prop_dir * 9.5 + Vector3.UP * 1.9, damage * 0.80)
        velocity += prop_dir * 0.8
    combo_step = 0
    combo_window = 0.0

func _grab_or_throw() -> void:
    if traversal_lock > 0.0:
        return
    if held_target != null and is_instance_valid(held_target):
        var dir: Vector3 = -global_basis.z
        held_target.set_held(false)
        held_target.take_hit(dir * 13.5 + Vector3.UP * 5.2, 24.0)
        held_target = null
        return

    var target = _find_grabbable(1.90)
    if target == null:
        return
    held_target = target
    if target.is_in_group("enemy"):
        engaged_target = target
        engage_timer = 2.0
    target.set_held(true)

func _update_held_target() -> void:
    var hold_height := 1.20
    if held_target.is_in_group("physics_prop"):
        hold_height = 1.40
    var hold_pos: Vector3 = global_position - global_basis.z * 1.12 + Vector3.UP * hold_height
    held_target.global_position = held_target.global_position.lerp(hold_pos, 0.52)
    held_target.rotation.y = rotation.y

func _find_grabbable(radius: float):
    var best = null
    var best_score: float = -9999.0
    var forward: Vector3 = -global_basis.z
    var candidates: Array = []
    candidates.append_array(get_tree().get_nodes_in_group("enemy"))
    candidates.append_array(get_tree().get_nodes_in_group("physics_prop"))
    for node in candidates:
        if not is_instance_valid(node):
            continue
        if node.is_in_group("enemy") and node.dead:
            continue
        if node.is_in_group("physics_prop") and node.mass > 110.0:
            continue
        var offset: Vector3 = node.global_position - global_position
        var dist: float = offset.length()
        if dist > radius:
            continue
        var dir: Vector3 = offset.normalized()
        var score: float = forward.dot(dir) * 2.2 - dist * 0.60
        if score > best_score:
            best_score = score
            best = node
    return best

func _find_prop(radius: float):
    var best = null
    var best_score: float = -9999.0
    var forward: Vector3 = -global_basis.z
    for prop in get_tree().get_nodes_in_group("physics_prop"):
        if not is_instance_valid(prop):
            continue
        var offset: Vector3 = prop.global_position - global_position
        var dist: float = offset.length()
        if dist > radius:
            continue
        var dir: Vector3 = offset.normalized()
        var score: float = forward.dot(dir) * 2.0 - dist * 0.55
        if score > best_score:
            best_score = score
            best = prop
    return best

func _find_target(radius: float):
    if engaged_target != null and is_instance_valid(engaged_target):
        var d: float = global_position.distance_to(engaged_target.global_position)
        if d <= radius * 1.30:
            return engaged_target
    var best = null
    var best_score: float = -9999.0
    var forward: Vector3 = -global_basis.z
    for enemy in get_tree().get_nodes_in_group("enemy"):
        if not enemy.visible or enemy.dead:
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
    if _rig == null:
        return
    var planar := Vector2(velocity.x, velocity.z).length()
    var attack_amount := attack_anim / 0.28 if attack_anim > 0.0 else 0.0
    var hit_amount := hit_anim / 0.28 if hit_anim > 0.0 else 0.0
    _rig.animate(delta, planar, speed, attack_amount, hit_amount, health <= 0.0)

func _update_hud() -> void:
    if hud == null:
        return
    if hud.has_method("set_health"):
        hud.set_health(health / max_health)
    if hud.has_method("set_target"):
        hud.set_target(engaged_target)
    if held_target != null and is_instance_valid(held_target):
        if held_target.is_in_group("enemy"):
            hud.set_context("GRAPPLE // HIT TO THROW")
        elif held_target.is_in_group("physics_prop"):
            hud.set_context("LOAD HELD // HIT TO LAUNCH")
    elif traversal_lock <= 0.0 and engage_timer <= 0.0:
        hud.set_context("POWER // COMBAT // MACHINES")
