class_name FoundryEnemy
extends CharacterBody3D

const GeomUtil = preload("res://scripts/geom.gd")
const HumanoidRigScript = preload("res://scripts/humanoid_rig.gd")
const ImpactFx = preload("res://scripts/impact_fx.gd")

var target: Node3D
var health := 100.0
var speed := 3.9
var attack_cooldown := 0.0
var attack_windup := 0.0
var attack_landed := false
var stagger := 0.0
var hit_anim := 0.0
var held := false
var dead := false
var flank_sign := 1.0
var _rig

func _ready() -> void:
    add_to_group("enemy")
    collision_layer = 4
    collision_mask = 1 | 2 | 8
    var collision := GeomUtil.add_capsule_collision(self, 0.42, 1.70)
    collision.position.y = 0.85
    flank_sign = -1.0 if int(get_instance_id()) % 2 == 0 else 1.0
    _rig = HumanoidRigScript.new()
    add_child(_rig)
    _rig.configure(false)
    _rig.set_attack_side(flank_sign)

func set_target(node: Node3D) -> void:
    target = node

func take_hit(force: Vector3, damage: float) -> void:
    if dead:
        return
    health -= damage
    stagger = 0.32
    hit_anim = 0.30
    attack_windup = 0.0
    attack_landed = false
    velocity += force
    var fx_dir := force.normalized() if force.length_squared() > 0.001 else Vector3.UP
    ImpactFx.spawn(get_parent(), global_position + Vector3.UP * 1.15, fx_dir, Color(0.86, 0.48, 0.16), clampf(damage / 18.0, 0.8, 3.0), 8)
    if health <= 0.0:
        dead = true
        collision_layer = 0
        collision_mask = 1 | 8
        velocity += force * 0.75
        ImpactFx.spawn(get_parent(), global_position + Vector3.UP * 0.9, fx_dir, Color(0.55, 0.34, 0.18), 2.6, 11)

func receive_hazard_hit(damage: float, impulse: Vector3) -> void:
    take_hit(impulse, damage)

func set_held(value: bool) -> void:
    held = value
    if held:
        velocity = Vector3.ZERO
        attack_windup = 0.0

func _physics_process(delta: float) -> void:
    attack_cooldown = maxf(0.0, attack_cooldown - delta)
    stagger = maxf(0.0, stagger - delta)
    hit_anim = maxf(0.0, hit_anim - delta)

    if held:
        velocity = Vector3.ZERO
        _animate(delta)
        return

    if not is_on_floor():
        velocity.y -= 24.0 * delta

    if dead:
        velocity.x = move_toward(velocity.x, 0.0, 5.5 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 5.5 * delta)
        move_and_slide()
        _animate(delta)
        return

    if target == null or not is_instance_valid(target):
        move_and_slide()
        _animate(delta)
        return

    var to_target: Vector3 = target.global_position - global_position
    to_target.y = 0.0
    var dist: float = to_target.length()

    if attack_windup > 0.0:
        var previous := attack_windup
        attack_windup = maxf(0.0, attack_windup - delta)
        velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 24.0 * delta)
        if to_target.length_squared() > 0.01:
            var attack_dir := to_target.normalized()
            rotation.y = lerp_angle(rotation.y, atan2(-attack_dir.x, -attack_dir.z), 0.34)
        if previous > 0.17 and attack_windup <= 0.17 and not attack_landed:
            attack_landed = true
            if dist <= 1.82 and target.has_method("receive_enemy_hit"):
                target.receive_enemy_hit(14.0)
                if target is CharacterBody3D:
                    target.velocity += to_target.normalized() * 2.4
        move_and_slide()
        _animate(delta)
        return

    if dist > 1.52 and stagger <= 0.0:
        var dir: Vector3 = to_target.normalized()
        var tangent := Vector3(-dir.z, 0.0, dir.x) * flank_sign
        var separation := _separation_force()
        var flank_weight := clampf((dist - 1.5) / 6.0, 0.0, 0.42)
        var move_dir := (dir + tangent * flank_weight + separation * 0.85).normalized()
        velocity.x = move_toward(velocity.x, move_dir.x * speed, 18.0 * delta)
        velocity.z = move_toward(velocity.z, move_dir.z * speed, 18.0 * delta)
        rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 0.16)
    else:
        velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
        if dist <= 1.68 and attack_cooldown <= 0.0 and stagger <= 0.0:
            attack_cooldown = 1.02
            attack_windup = 0.38
            attack_landed = false
            flank_sign *= -1.0
            if _rig != null:
                _rig.set_attack_side(flank_sign)

    move_and_slide()
    _animate(delta)

func _separation_force() -> Vector3:
    var force := Vector3.ZERO
    for other in get_tree().get_nodes_in_group("enemy"):
        if other == self or not is_instance_valid(other) or other.dead:
            continue
        var away: Vector3 = global_position - other.global_position
        away.y = 0.0
        var d := away.length()
        if d > 0.01 and d < 2.15:
            force += away.normalized() * (1.0 - d / 2.15)
    return force

func _animate(delta: float) -> void:
    if _rig == null:
        return
    var planar := Vector2(velocity.x, velocity.z).length()
    var attack_amount := attack_windup / 0.38 if attack_windup > 0.0 else 0.0
    var hit_amount := hit_anim / 0.30 if hit_anim > 0.0 else 0.0
    _rig.animate(delta, planar, speed, attack_amount, hit_amount, dead)
