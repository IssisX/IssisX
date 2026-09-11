class_name Excavator
extends CharacterBody3D

const GeomUtil = preload("res://scripts/geom.gd")
const ImpactFx = preload("res://scripts/impact_fx.gd")
const VisualBuilder = preload("res://scripts/excavator_visual.gd")

signal player_entered(machine)
signal player_exited(machine)
signal machine_disabled(machine)

var player_driver: Node3D
var enemy_driver: Node3D
var hud
var camera_rig

var drive_speed := 7.0
var turn_speed := 1.15
var boom_angle := -0.24
var stick_angle := 0.42
var tool_angle := -0.18
var arm_yaw := 0.0
var ai_time := 0.0

var chassis_health := 500.0
var hydraulic_health := 260.0
var track_health := 320.0
var disabled := false
var held_load

var _boom: Node3D
var _stick: Node3D
var _tool: Node3D
var _thumb: Node3D
var _grip_anchor: Node3D
var _impact_probe: Area3D
var _work_light: OmniLight3D
var _engine_cover: MeshInstance3D
var _impact_cooldown := 0.0
var _damage_fx_cooldown := 0.0
var _telemetry_timer := 0.0
var _tool_tip_last := Vector3.ZERO
var _tool_tip_velocity := Vector3.ZERO
var _tool_tip_speed := 0.0
var _tool_motion_ready := false

func _ready() -> void:
    add_to_group("machine")
    collision_layer = 2
    collision_mask = 1 | 4 | 8
    var collision := GeomUtil.add_box_collision(self, Vector3(2.95, 1.45, 4.5))
    collision.position.y = 0.90
    var nodes := VisualBuilder.build(self)
    _boom = nodes.boom
    _stick = nodes.stick
    _tool = nodes.tool
    _thumb = nodes.thumb
    _grip_anchor = nodes.grip_anchor
    _impact_probe = nodes.impact_probe
    _work_light = nodes.work_light
    _engine_cover = nodes.engine_cover

func configure(controls, camera) -> void:
    hud = controls
    camera_rig = camera

func set_enemy_driver(driver: Node3D) -> void:
    enemy_driver = driver
    if driver != null:
        driver.visible = false
        driver.process_mode = Node.PROCESS_MODE_DISABLED

func is_player_driven() -> bool:
    return player_driver != null

func get_health_ratio() -> float:
    return clampf(chassis_health / 500.0, 0.0, 1.0)

func get_hydraulic_ratio() -> float:
    return clampf(hydraulic_health / 260.0, 0.0, 1.0)

func get_track_ratio() -> float:
    return clampf(track_health / 320.0, 0.0, 1.0)

func get_tool_force() -> float:
    var chassis_speed := Vector3(velocity.x, 0.0, velocity.z).length()
    return 16.0 + chassis_speed * 10.0 + minf(_tool_tip_speed, 15.0) * 5.8

func is_holding_load() -> bool:
    return held_load != null and is_instance_valid(held_load)

func try_enter(player: Node3D) -> bool:
    if disabled or global_position.distance_to(player.global_position) > 3.3:
        return false
    if enemy_driver != null:
        enemy_driver.visible = true
        enemy_driver.process_mode = Node.PROCESS_MODE_INHERIT
        enemy_driver.global_position = global_position + global_basis.x * 2.2 + Vector3.UP * 0.22
        if enemy_driver.has_method("take_hit"):
            enemy_driver.take_hit(global_basis.x * 8.0 + Vector3.UP * 2.5, 40.0)
        enemy_driver = null
    player_driver = player
    player.visible = false
    player.process_mode = Node.PROCESS_MODE_DISABLED
    if hud != null:
        hud.set_machine_mode(true)
        hud.set_context("DIRECT BOOM // PHYSICAL BUCKET // HYDRAULIC THUMB")
    player_entered.emit(self)
    return true

func exit_player() -> void:
    if player_driver == null:
        return
    _release_load(false)
    var player := player_driver
    player_driver = null
    player.visible = true
    player.process_mode = Node.PROCESS_MODE_INHERIT
    player.global_position = global_position + global_basis.x * 2.8 + Vector3.UP * 0.22
    if hud != null:
        hud.set_machine_mode(false)
        hud.set_context("POWER // COMBAT // MACHINES")
    player_exited.emit(self)

func receive_enemy_hit(damage: float) -> void:
    _apply_machine_damage(damage, Vector3.UP)

func receive_hazard_hit(damage: float, impulse: Vector3) -> void:
    velocity += impulse * 0.22
    _apply_machine_damage(damage * 0.72, impulse.normalized() if impulse.length_squared() > 0.01 else Vector3.UP)

func machine_hit(amount: float, direction: Vector3) -> void:
    velocity += direction.normalized() * minf(amount * 0.018, 3.8)
    _apply_machine_damage(amount * 0.58, direction)

func _apply_machine_damage(amount: float, direction: Vector3) -> void:
    if disabled:
        return
    chassis_health = maxf(0.0, chassis_health - amount)
    var side_load := absf(direction.dot(global_basis.x))
    var vertical_load := absf(direction.y)
    track_health = maxf(0.0, track_health - amount * (0.18 + side_load * 0.36))
    hydraulic_health = maxf(0.0, hydraulic_health - amount * (0.12 + vertical_load * 0.28))
    _damage_fx_cooldown = 0.0
    ImpactFx.spawn(get_parent(), global_position + Vector3.UP * 1.7, direction, Color(1.0, 0.48, 0.08), clampf(amount / 16.0, 0.8, 4.0), 10)
    _refresh_damage_visuals()
    if chassis_health <= 0.0:
        disabled = true
        _release_load(true)
        velocity *= 0.2
        if _work_light != null:
            _work_light.light_energy = 0.0
        machine_disabled.emit(self)

func _refresh_damage_visuals() -> void:
    if _engine_cover == null:
        return
    var c := Color(0.68, 0.37, 0.045)
    if get_health_ratio() < 0.65:
        c = Color(0.55, 0.24, 0.035)
    if get_health_ratio() < 0.32:
        c = Color(0.28, 0.11, 0.025)
    _engine_cover.material_override = GeomUtil.material(c, 0.78, 0.18)

func _physics_process(delta: float) -> void:
    _impact_cooldown = maxf(0.0, _impact_cooldown - delta)
    _damage_fx_cooldown = maxf(0.0, _damage_fx_cooldown - delta)
    _telemetry_timer = maxf(0.0, _telemetry_timer - delta)

    if disabled:
        velocity.x = move_toward(velocity.x, 0.0, 7.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 7.0 * delta)
    elif player_driver != null:
        _player_control(delta)
    elif enemy_driver != null:
        _enemy_control(delta)
    else:
        velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)

    if not is_on_floor():
        velocity.y -= 26.0 * delta
    move_and_slide()
    _apply_arm_pose()
    _update_tool_motion(delta)
    _update_held_load()
    _resolve_tool_impacts()
    _update_damage_fx()
    _update_telemetry()

func _player_control(delta: float) -> void:
    if hud == null or camera_rig == null:
        return
    var track_ratio := maxf(get_track_ratio(), 0.18)
    var hydraulic_ratio := maxf(get_hydraulic_ratio(), 0.22)
    var axis: Vector2 = hud.move_axis
    var throttle: float = -axis.y
    var steering: float = axis.x
    var forward: Vector3 = -global_basis.z
    velocity.x = forward.x * throttle * drive_speed * track_ratio
    velocity.z = forward.z * throttle * drive_speed * track_ratio
    rotation.y -= steering * turn_speed * track_ratio * delta

    var look: Vector2 = hud.consume_look()
    arm_yaw -= look.x * 0.0032 * hydraulic_ratio
    boom_angle += look.y * 0.0026 * hydraulic_ratio
    arm_yaw = clamp(arm_yaw, -1.25, 1.25)
    boom_angle = clamp(boom_angle, -0.95, 0.42)

    if hud.consume_attack():
        stick_angle -= 0.36 * hydraulic_ratio
        tool_angle -= 0.30 * hydraulic_ratio
        _impact_cooldown = 0.0
    if hud.consume_grab():
        if is_holding_load():
            _release_load(true)
        elif not _try_grip_load():
            stick_angle += 0.24 * hydraulic_ratio
            tool_angle += 0.28 * hydraulic_ratio
    if hud.consume_use() or Input.is_physical_key_pressed(KEY_E):
        exit_player()

    stick_angle = clamp(stick_angle, -0.55, 1.00)
    tool_angle = clamp(tool_angle, -1.0, 0.72)

func _enemy_control(delta: float) -> void:
    ai_time += delta
    var target := get_tree().get_first_node_in_group("player")
    if target == null:
        return
    var to_target: Vector3 = target.global_position - global_position
    to_target.y = 0.0
    if to_target.length() > 0.1:
        var desired: float = atan2(-to_target.x, -to_target.z)
        rotation.y = lerp_angle(rotation.y, desired, 0.018)
    var forward: Vector3 = -global_basis.z
    var throttle: float = 1.0 if to_target.length() > 7.0 else 0.0
    var track_ratio := maxf(get_track_ratio(), 0.22)
    velocity.x = forward.x * throttle * drive_speed * 0.48 * track_ratio
    velocity.z = forward.z * throttle * drive_speed * 0.48 * track_ratio
    var hydro := maxf(get_hydraulic_ratio(), 0.24)
    arm_yaw = sin(ai_time * 0.74) * 0.46 * hydro
    boom_angle = -0.35 + sin(ai_time * 0.88) * 0.18 * hydro
    stick_angle = 0.30 + sin(ai_time * 1.14) * 0.22 * hydro
    tool_angle = -0.15 + sin(ai_time * 1.31) * 0.22 * hydro

func _apply_arm_pose() -> void:
    _boom.rotation = Vector3(boom_angle, arm_yaw, 0.0)
    _stick.rotation.x = stick_angle
    _tool.rotation.x = tool_angle
    if _thumb != null:
        _thumb.rotation.x = -0.76 if is_holding_load() else -0.05

func _update_tool_motion(delta: float) -> void:
    var tip := _tool.to_global(Vector3(0.0, -0.20, -1.10))
    if not _tool_motion_ready:
        _tool_tip_last = tip
        _tool_motion_ready = true
        return
    _tool_tip_velocity = (tip - _tool_tip_last) / maxf(delta, 0.001)
    _tool_tip_speed = _tool_tip_velocity.length()
    _tool_tip_last = tip

func _try_grip_load() -> bool:
    var best = null
    var best_distance := INF
    for body in _impact_probe.get_overlapping_bodies():
        if body == self or not body.is_in_group("physics_prop") or body.mass > 420.0:
            continue
        var d := body.global_position.distance_to(_grip_anchor.global_position)
        if d < best_distance:
            best_distance = d
            best = body
    if best == null:
        return false
    held_load = best
    if held_load.has_method("set_held"):
        held_load.set_held(true)
    hud.set_context("LOAD CLAMPED // MOVE ARM TO CARRY // CLAMP TO RELEASE")
    return true

func _update_held_load() -> void:
    if not is_holding_load():
        held_load = null
        return
    held_load.global_position = _grip_anchor.global_position
    held_load.global_basis = _grip_anchor.global_basis

func _release_load(with_throw: bool) -> void:
    if not is_holding_load():
        held_load = null
        return
    var load = held_load
    held_load = null
    if load.has_method("set_held"):
        load.set_held(false)
    if with_throw and load is RigidBody3D:
        load.linear_velocity = _tool_tip_velocity + velocity * 0.85
        load.angular_velocity = Vector3(_tool_tip_velocity.z, 0.8, -_tool_tip_velocity.x) * 0.16
    if hud != null:
        hud.set_context("DIRECT BOOM // PHYSICAL BUCKET // HYDRAULIC THUMB")

func _resolve_tool_impacts() -> void:
    if _impact_cooldown > 0.0:
        return
    var chassis_speed := Vector3(velocity.x, 0.0, velocity.z).length()
    if chassis_speed < 0.45 and _tool_tip_speed < 1.0:
        return
    var force := get_tool_force()
    var impact_dir := _tool_tip_velocity.normalized() if _tool_tip_velocity.length_squared() > 0.04 else -_tool.global_basis.z
    for body in _impact_probe.get_overlapping_bodies():
        if body == self or body == held_load:
            continue
        if body.has_method("machine_hit"):
            body.machine_hit(force, impact_dir)
            _impact_cooldown = 0.15
        elif body.has_method("take_hit"):
            var push := impact_dir * (10.0 + minf(_tool_tip_speed, 12.0)) + Vector3.UP * 4.5
            body.take_hit(push, 42.0 + minf(_tool_tip_speed, 12.0) * 1.2)
            _impact_cooldown = 0.15

func _update_damage_fx() -> void:
    if get_health_ratio() > 0.58 or _damage_fx_cooldown > 0.0:
        return
    _damage_fx_cooldown = 0.65 if get_health_ratio() > 0.28 else 0.32
    var color := Color(0.30, 0.28, 0.24) if get_health_ratio() > 0.28 else Color(0.12, 0.11, 0.10)
    ImpactFx.spawn(get_parent(), global_position + Vector3(0.75, 2.7, 0.6), Vector3.UP, color, 1.3, 5)
    if _work_light != null and get_health_ratio() < 0.32:
        _work_light.light_energy = 0.7 + absf(sin(Time.get_ticks_msec() * 0.012)) * 1.1

func _update_telemetry() -> void:
    if hud == null or player_driver == null or not hud.has_method("set_machine_telemetry") or _telemetry_timer > 0.0:
        return
    _telemetry_timer = 0.08
    hud.set_machine_telemetry(
        get_health_ratio(),
        get_hydraulic_ratio(),
        get_track_ratio(),
        clampf(get_tool_force() / 130.0, 0.0, 1.0),
        is_holding_load()
    )
