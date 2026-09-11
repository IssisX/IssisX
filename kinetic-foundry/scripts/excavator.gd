class_name Excavator
extends CharacterBody3D

signal player_entered(machine: Excavator)
signal player_exited(machine: Excavator)

var player_driver: Node3D
var enemy_driver: Node3D
var hud: MobileHud
var camera_rig: CameraRig

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

func _ready() -> void:
    add_to_group("machine")
    collision_layer = 2
    collision_mask = 1 | 4 | 8
    Geom.add_box_collision(
        self,
        Vector3(2.75, 1.25, 4.2)
    )
    _build_visual()

func configure(
        controls: MobileHud,
        camera: CameraRig
) -> void:
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
        enemy_driver.global_position = (
            global_position
            + global_basis.x * 2.2
            + Vector3.UP * 0.6
        )
        if enemy_driver.has_method("take_hit"):
            enemy_driver.take_hit(
                global_basis.x * 8.0 + Vector3.UP * 2.5,
                40.0
            )
        enemy_driver = null
    player_driver = player
    player.visible = false
    player.process_mode = Node.PROCESS_MODE_DISABLED
    player_entered.emit(self)
    return true

func exit_player() -> void:
    if player_driver == null:
        return
    var player := player_driver
    player_driver = null
    player.visible = true
    player.process_mode = Node.PROCESS_MODE_INHERIT
    player.global_position = (
        global_position
        + global_basis.x * 2.6
        + Vector3.UP * 0.7
    )
    player_exited.emit(self)

func _build_visual() -> void:
    var chassis := Geom.box_mesh(
        Vector3(2.7, 1.1, 4.1),
        Color(0.82, 0.52, 0.08),
        0.62,
        0.15
    )
    chassis.position.y = 1.05
    add_child(chassis)
    for side in [-1.0, 1.0]:
        var track := Geom.box_mesh(
            Vector3(0.62, 0.72, 4.35),
            Color(0.07, 0.08, 0.07),
            0.94,
            0.10
        )
        track.position = Vector3(side * 1.42, 0.56, 0.0)
        add_child(track)
    var cab := Geom.box_mesh(
        Vector3(1.55, 1.75, 1.70),
        Color(0.17, 0.19, 0.18),
        0.52,
        0.22
    )
    cab.position = Vector3(-0.56, 2.35, 0.40)
    add_child(cab)
    _boom = Node3D.new()
    _boom.position = Vector3(0.55, 2.15, -1.05)
    add_child(_boom)
    var boom_mesh := Geom.box_mesh(
        Vector3(0.52, 0.58, 4.5),
        Color(0.86, 0.55, 0.08),
        0.60,
        0.12
    )
    boom_mesh.position.z = -2.05
    _boom.add_child(boom_mesh)
    _stick = Node3D.new()
    _stick.position = Vector3(0.0, 0.0, -4.1)
    _boom.add_child(_stick)
    var stick_mesh := Geom.box_mesh(
        Vector3(0.42, 0.50, 3.4),
        Color(0.86, 0.55, 0.08),
        0.60,
        0.12
    )
    stick_mesh.position.z = -1.55
    _stick.add_child(stick_mesh)
    _tool = Node3D.new()
    _tool.position = Vector3(0.0, 0.0, -3.1)
    _stick.add_child(_tool)
    var bucket := Geom.box_mesh(
        Vector3(1.75, 1.05, 1.22),
        Color(0.30, 0.31, 0.28),
        0.82,
        0.34
    )
    bucket.position.z = -0.46
    _tool.add_child(bucket)
    _impact_probe = Area3D.new()
    _impact_probe.collision_layer = 0
    _impact_probe.collision_mask = 4 | 8
    _tool.add_child(_impact_probe)
    var shape := BoxShape3D.new()
    shape.size = Vector3(2.0, 1.35, 1.7)
    var collision := CollisionShape3D.new()
    collision.shape = shape
    collision.position.z = -0.45
    _impact_probe.add_child(collision)

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
    _resolve_tool_impacts()

func _player_control(delta: float) -> void:
    if hud == null or camera_rig == null:
        return
    var axis := hud.move_axis
    var throttle := -axis.y
    var steering := axis.x
    var forward := -global_basis.z
    velocity.x = forward.x * throttle * drive_speed
    velocity.z = forward.z * throttle * drive_speed
    rotation.y -= steering * turn_speed * delta
    var look := hud.consume_look()
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
    var to_target := target.global_position - global_position
    to_target.y = 0.0
    if to_target.length() > 0.1:
        var desired := atan2(-to_target.x, -to_target.z)
        rotation.y = lerp_angle(rotation.y, desired, 0.018)
    var forward := -global_basis.z
    var throttle := 1.0 if to_target.length() > 7.0 else 0.0
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

func _resolve_tool_impacts() -> void:
    if _impact_cooldown > 0.0:
        return
    var speed := Vector3(velocity.x, 0.0, velocity.z).length()
    var swing := absf(stick_angle) + absf(boom_angle)
    var force := 28.0 + speed * 9.0 + swing * 18.0
    for body in _impact_probe.get_overlapping_bodies():
        if body == self:
            continue
        if body.has_method("machine_hit"):
            var dir := -_tool.global_basis.z
            body.machine_hit(force, dir)
            _impact_cooldown = 0.16
        elif body.has_method("take_hit"):
            var push := -_tool.global_basis.z * 15.0
            push += Vector3.UP * 4.5
            body.take_hit(push, 55.0)
            _impact_cooldown = 0.16
