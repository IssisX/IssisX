class_name Excavator
extends CharacterBody3D

const GeomUtil = preload("res://scripts/geom.gd")

signal player_entered(machine)
signal player_exited(machine)

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

var _boom: Node3D
var _stick: Node3D
var _tool: Node3D
var _impact_probe: Area3D
var _impact_cooldown := 0.0
var _tool_tip_last := Vector3.ZERO
var _tool_tip_speed := 0.0
var _tool_motion_ready := false

func _ready() -> void:
    add_to_group("machine")
    collision_layer = 2
    collision_mask = 1 | 4 | 8
    var collision := GeomUtil.add_box_collision(self, Vector3(2.95, 1.45, 4.5))
    collision.position.y = 0.90
    _build_visual()

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

func try_enter(player: Node3D) -> bool:
    if global_position.distance_to(player.global_position) > 3.3:
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
    if hud != null and hud.has_method("set_machine_mode"):
        hud.set_machine_mode(true)
    if hud != null and hud.has_method("set_context"):
        hud.set_context("DIRECT BOOM // BUCKET FORCE")
    player_entered.emit(self)
    return true

func exit_player() -> void:
    if player_driver == null:
        return
    var player := player_driver
    player_driver = null
    player.visible = true
    player.process_mode = Node.PROCESS_MODE_INHERIT
    player.global_position = global_position + global_basis.x * 2.8 + Vector3.UP * 0.22
    if hud != null and hud.has_method("set_machine_mode"):
        hud.set_machine_mode(false)
    if hud != null and hud.has_method("set_context"):
        hud.set_context("POWER // COMBAT // MACHINES")
    player_exited.emit(self)

func _build_visual() -> void:
    var undercarriage := GeomUtil.box_mesh(Vector3(3.25, 0.46, 4.45), Color(0.09, 0.095, 0.085), 0.94, 0.18)
    undercarriage.position.y = 0.62
    add_child(undercarriage)

    for side in [-1.0, 1.0]:
        var track := GeomUtil.box_mesh(Vector3(0.68, 0.82, 4.55), Color(0.055, 0.06, 0.055), 0.98, 0.22)
        track.position = Vector3(side * 1.43, 0.58, 0.0)
        add_child(track)
        for shoe_i in 8:
            var shoe := GeomUtil.box_mesh(Vector3(0.78, 0.09, 0.46), Color(0.16, 0.17, 0.15), 0.94, 0.28)
            shoe.position = Vector3(side * 1.43, 1.02, -1.62 + float(shoe_i) * 0.47)
            add_child(shoe)

    var turntable := GeomUtil.capsule_mesh(1.15, 0.44, Color(0.18, 0.19, 0.17))
    turntable.scale = Vector3(1.0, 0.45, 1.0)
    turntable.position.y = 1.10
    add_child(turntable)

    var chassis := GeomUtil.box_mesh(Vector3(2.85, 1.16, 3.72), Color(0.80, 0.47, 0.055), 0.66, 0.16)
    chassis.position = Vector3(0.0, 1.65, 0.16)
    add_child(chassis)

    var counterweight := GeomUtil.box_mesh(Vector3(2.75, 1.34, 1.22), Color(0.74, 0.40, 0.045), 0.72, 0.18)
    counterweight.position = Vector3(0.0, 1.82, 1.55)
    add_child(counterweight)

    var engine_cover := GeomUtil.box_mesh(Vector3(1.18, 1.18, 1.65), Color(0.68, 0.37, 0.045), 0.70, 0.14)
    engine_cover.position = Vector3(0.70, 2.15, 0.58)
    add_child(engine_cover)

    var cab_frame := GeomUtil.box_mesh(Vector3(1.46, 1.90, 1.72), Color(0.085, 0.095, 0.09), 0.56, 0.28)
    cab_frame.position = Vector3(-0.66, 2.48, 0.34)
    add_child(cab_frame)

    var windshield := GeomUtil.box_mesh(Vector3(1.08, 1.34, 0.055), Color(0.10, 0.20, 0.22), 0.22, 0.40)
    windshield.position = Vector3(-0.66, 2.53, -0.55)
    add_child(windshield)

    var side_window := GeomUtil.box_mesh(Vector3(0.055, 1.28, 1.04), Color(0.10, 0.20, 0.22), 0.22, 0.40)
    side_window.position = Vector3(-1.42, 2.54, 0.18)
    add_child(side_window)

    var work_light := OmniLight3D.new()
    work_light.position = Vector3(-0.74, 3.47, -0.58)
    work_light.light_color = Color(1.0, 0.72, 0.38)
    work_light.light_energy = 1.8
    work_light.omni_range = 7.5
    work_light.shadow_enabled = false
    add_child(work_light)

    _boom = Node3D.new()
    _boom.position = Vector3(0.62, 2.37, -0.88)
    add_child(_boom)
    var boom_joint := GeomUtil.sphere_mesh(0.42, Color(0.18, 0.19, 0.17))
    _boom.add_child(boom_joint)
    var boom_mesh := GeomUtil.box_mesh(Vector3(0.58, 0.66, 4.72), Color(0.84, 0.49, 0.055), 0.61, 0.14)
    boom_mesh.position.z = -2.15
    _boom.add_child(boom_mesh)
    var boom_rod := GeomUtil.capsule_mesh(0.095, 3.55, Color(0.68, 0.69, 0.64))
    boom_rod.rotation.x = PI * 0.5
    boom_rod.position = Vector3(0.42, 0.20, -1.72)
    _boom.add_child(boom_rod)

    _stick = Node3D.new()
    _stick.position = Vector3(0.0, 0.0, -4.28)
    _boom.add_child(_stick)
    var stick_joint := GeomUtil.sphere_mesh(0.34, Color(0.18, 0.19, 0.17))
    _stick.add_child(stick_joint)
    var stick_mesh := GeomUtil.box_mesh(Vector3(0.46, 0.54, 3.58), Color(0.84, 0.49, 0.055), 0.61, 0.14)
    stick_mesh.position.z = -1.65
    _stick.add_child(stick_mesh)
    var stick_rod := GeomUtil.capsule_mesh(0.075, 2.70, Color(0.69, 0.70, 0.66))
    stick_rod.rotation.x = PI * 0.5
    stick_rod.position = Vector3(-0.34, 0.18, -1.28)
    _stick.add_child(stick_rod)

    _tool = Node3D.new()
    _tool.position = Vector3(0.0, 0.0, -3.28)
    _stick.add_child(_tool)
    var bucket := GeomUtil.box_mesh(Vector3(1.86, 1.12, 1.30), Color(0.24, 0.25, 0.225), 0.90, 0.38)
    bucket.position = Vector3(0.0, -0.12, -0.52)
    _tool.add_child(bucket)
    for tooth_i in 4:
        var tooth := GeomUtil.box_mesh(Vector3(0.22, 0.20, 0.54), Color(0.17, 0.18, 0.16), 0.94, 0.42)
        tooth.position = Vector3(-0.66 + float(tooth_i) * 0.44, -0.46, -1.08)
        tooth.rotation.x = -0.22
        _tool.add_child(tooth)

    _impact_probe = Area3D.new()
    _impact_probe.collision_layer = 0
    _impact_probe.collision_mask = 4 | 8
    _tool.add_child(_impact_probe)
    var shape := BoxShape3D.new()
    shape.size = Vector3(2.0, 1.35, 1.7)
    var impact_collision := CollisionShape3D.new()
    impact_collision.shape = shape
    impact_collision.position.z = -0.45
    _impact_probe.add_child(impact_collision)

func _physics_process(delta: float) -> void:
    _impact_cooldown = maxf(0.0, _impact_cooldown - delta)
    if player_driver != null:
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
    _resolve_tool_impacts()

func _player_control(delta: float) -> void:
    if hud == null or camera_rig == null:
        return
    var axis: Vector2 = hud.move_axis
    var throttle: float = -axis.y
    var steering: float = axis.x
    var forward: Vector3 = -global_basis.z
    velocity.x = forward.x * throttle * drive_speed
    velocity.z = forward.z * throttle * drive_speed
    rotation.y -= steering * turn_speed * delta
    var look: Vector2 = hud.consume_look()
    arm_yaw -= look.x * 0.0032
    boom_angle += look.y * 0.0026
    arm_yaw = clamp(arm_yaw, -1.25, 1.25)
    boom_angle = clamp(boom_angle, -0.95, 0.42)
    if hud.consume_attack():
        stick_angle -= 0.36
        tool_angle -= 0.30
        _impact_cooldown = 0.0
    if hud.consume_grab():
        stick_angle += 0.28
        tool_angle += 0.34
    if hud.consume_use():
        exit_player()
    elif Input.is_physical_key_pressed(KEY_E):
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
    velocity.x = forward.x * throttle * drive_speed * 0.48
    velocity.z = forward.z * throttle * drive_speed * 0.48
    arm_yaw = sin(ai_time * 0.74) * 0.46
    boom_angle = -0.35 + sin(ai_time * 0.88) * 0.18
    stick_angle = 0.30 + sin(ai_time * 1.14) * 0.22
    tool_angle = -0.15 + sin(ai_time * 1.31) * 0.22

func _apply_arm_pose() -> void:
    _boom.rotation = Vector3(boom_angle, arm_yaw, 0.0)
    _stick.rotation.x = stick_angle
    _tool.rotation.x = tool_angle

func _update_tool_motion(delta: float) -> void:
    var tip := _tool.to_global(Vector3(0.0, -0.20, -1.10))
    if not _tool_motion_ready:
        _tool_tip_last = tip
        _tool_motion_ready = true
        _tool_tip_speed = 0.0
        return
    _tool_tip_speed = tip.distance_to(_tool_tip_last) / maxf(delta, 0.001)
    _tool_tip_last = tip

func _resolve_tool_impacts() -> void:
    if _impact_cooldown > 0.0:
        return
    var chassis_speed := Vector3(velocity.x, 0.0, velocity.z).length()
    if chassis_speed < 0.45 and _tool_tip_speed < 1.0:
        return
    var force := 16.0 + chassis_speed * 10.0 + minf(_tool_tip_speed, 15.0) * 5.8
    var impact_dir := -_tool.global_basis.z
    for body in _impact_probe.get_overlapping_bodies():
        if body == self:
            continue
        if body.has_method("machine_hit"):
            body.machine_hit(force, impact_dir)
            _impact_cooldown = 0.15
        elif body.has_method("take_hit"):
            var push := impact_dir * (10.0 + minf(_tool_tip_speed, 12.0)) + Vector3.UP * 4.5
            body.take_hit(push, 42.0 + minf(_tool_tip_speed, 12.0) * 1.2)
            _impact_cooldown = 0.15
