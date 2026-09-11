class_name VisualCapture
extends Node

var game: Node3D
var capture_dir := ""
var anchor: Node3D

func begin(root: Node3D) -> void:
    game = root
    process_mode = Node.PROCESS_MODE_ALWAYS
    capture_dir = OS.get_environment("CAPTURE_DIR")
    if capture_dir.is_empty():
        capture_dir = ProjectSettings.globalize_path("res://captures/latest")
    DirAccess.make_dir_recursive_absolute(capture_dir)
    anchor = Node3D.new()
    anchor.name = "CaptureAnchor"
    game.add_child.call_deferred(anchor)
    call_deferred("_run")

func _run() -> void:
    await _settle_frames(5)
    _freeze_gameplay()

    _stage_yard_overview()
    await _settle_frames(10)
    _capture("01_yard_overview.png")

    _stage_combat()
    await _settle_frames(10)
    _capture("02_grounded_combat.png")

    _stage_excavator_load()
    await _settle_frames(10)
    _capture("03_excavator_load_control.png")

    _stage_structure_damage()
    await _settle_frames(7)
    _capture("04_progressive_structure_damage.png")

    _stage_structure_collapse()
    await _settle_physics_frames(58)
    await _settle_frames(8)
    _capture("05_collapse_aftermath.png")

    _stage_breach_gate()
    await _settle_physics_frames(24)
    await _settle_frames(8)
    _capture("06_breached_route.png")

    print("CAPTURE_SUITE_OK dir=", capture_dir)
    get_tree().quit(0)

func _freeze_gameplay() -> void:
    if game.player != null:
        game.player.process_mode = Node.PROCESS_MODE_DISABLED
    if game.excavator != null:
        game.excavator.process_mode = Node.PROCESS_MODE_DISABLED
    if game.mission != null:
        game.mission.process_mode = Node.PROCESS_MODE_DISABLED
    for enemy in get_tree().get_nodes_in_group("enemy"):
        enemy.process_mode = Node.PROCESS_MODE_DISABLED

func _stage_yard_overview() -> void:
    _show_all_enemies(true)
    game.player.visible = true
    game.player.global_position = Vector3(-9.0, 0.03, 12.5)
    game.excavator.global_position = Vector3(4.0, -0.17, -3.0)
    game.mission.stage = 0
    game.hud.set_machine_mode(false)
    game.hud.set_health(0.92)
    game.hud.set_target(null)
    game.hud.set_objective("BREAK THE YARD CREW", "CUT THROUGH THE WORK YARD AND EXPOSE THE MACHINE")
    game.hud.set_objective_progress(0.20)
    game.hud.set_context("POWER // COMBAT // MACHINES")
    anchor.global_position = Vector3(0.5, 1.0, -2.0)
    game.camera_rig.set_target(anchor)
    game.camera_rig.yaw = 0.70
    game.camera_rig.pitch = -0.34
    game.camera_rig.distance = 31.0
    game.camera_rig.height = 9.0

func _stage_combat() -> void:
    game.player.visible = true
    game.player.global_position = Vector3(-6.8, 0.03, 8.0)
    game.player.rotation.y = -0.42
    game.player.attack_anim = 0.14
    game.player.attack_side = 1.0
    if game.player._rig != null:
        game.player._rig.set_attack_side(1.0)
        game.player._animate(0.016)

    var visible_enemies := _visible_enemies()
    var positions := [
        Vector3(-4.55, 0.03, 6.15),
        Vector3(-8.65, 0.03, 5.65),
        Vector3(-3.25, 0.03, 9.15),
        Vector3(-10.15, 0.03, 8.5)
    ]
    for i in mini(visible_enemies.size(), positions.size()):
        var enemy = visible_enemies[i]
        enemy.global_position = positions[i]
        enemy.look_at(game.player.global_position, Vector3.UP)
        enemy.attack_windup = 0.20 if i == 0 else 0.0
        enemy.hit_anim = 0.12 if i == 1 else 0.0
        enemy._animate(0.016)
    for i in range(positions.size(), visible_enemies.size()):
        visible_enemies[i].visible = false

    game.player.engaged_target = visible_enemies[0] if not visible_enemies.is_empty() else null
    game.hud.set_machine_mode(false)
    game.hud.set_health(0.76)
    game.hud.set_target(game.player.engaged_target)
    game.hud.set_objective("BREAK THE YARD CREW", "ADAPTIVE LOCK // COMMIT // THROW THE ENVIRONMENT")
    game.hud.set_objective_progress(0.45)
    game.hud.set_context("COMBO 2 / 3 // HEAVY FINISHER READY")
    game.camera_rig.set_target(game.player)
    game.camera_rig.yaw = 0.50
    game.camera_rig.pitch = -0.20
    game.camera_rig.distance = 10.4
    game.camera_rig.height = 3.25

func _stage_excavator_load() -> void:
    game.player.visible = false
    _show_all_enemies(false)
    game.excavator.enemy_driver = null
    game.excavator.player_driver = game.player
    game.excavator.global_position = Vector3(4.0, -0.17, -3.0)
    game.excavator.arm_yaw = -0.26
    game.excavator.boom_angle = -0.55
    game.excavator.stick_angle = 0.72
    game.excavator.tool_angle = -0.42
    game.excavator._apply_arm_pose()

    var load = _first_prop()
    if load != null:
        game.excavator.held_load = load
        load.set_held(true)
        game.excavator._apply_arm_pose()
        game.excavator._update_held_load()

    game.mission.stage = 2
    game.hud.set_machine_mode(true)
    game.hud.set_target(null)
    game.hud.set_objective("DROP THE TRANSFER PLATFORM", "CARRY LOADS OR DRIVE THE BUCKET THROUGH THE SUPPORTS")
    game.hud.set_objective_progress(0.18)
    game.hud.set_machine_telemetry(0.88, 0.82, 0.91, 0.72, load != null)
    game.hud.set_context("LOAD CLAMPED // HYDRAULIC THUMB // DIRECT ARM")
    game.camera_rig.set_target(game.excavator)
    game.camera_rig.yaw = -0.72
    game.camera_rig.pitch = -0.27
    game.camera_rig.distance = 15.5
    game.camera_rig.height = 5.0

func _stage_structure_damage() -> void:
    _release_capture_load()
    game.structure.damage_support(0, 68.0, Vector3(1.0, 0.0, 0.22))
    game.structure.damage_support(2, 34.0, Vector3(0.72, 0.0, -0.34))
    game.mission.stage = 2
    game.hud.set_machine_mode(true)
    game.hud.set_objective("DROP THE TRANSFER PLATFORM", "LOAD PATH COMPROMISED // KEEP WORKING THE WEAK SIDE")
    game.hud.set_objective_progress(0.52)
    game.hud.set_machine_telemetry(0.84, 0.76, 0.90, 0.88, false)
    game.hud.set_context("STRUCTURE RACKING // SUPPORT 01 CRITICAL")
    anchor.global_position = game.structure.global_position + Vector3(0.0, 1.9, 0.0)
    game.camera_rig.set_target(anchor)
    game.camera_rig.yaw = -0.88
    game.camera_rig.pitch = -0.25
    game.camera_rig.distance = 15.0
    game.camera_rig.height = 4.8

func _stage_structure_collapse() -> void:
    game.structure.damage_support(0, 55.0, Vector3(1.0, 0.0, 0.25))
    game.structure.damage_support(2, 90.0, Vector3(1.0, 0.0, -0.20))
    game.mission.stage = 3
    game.hud.set_machine_mode(false)
    game.hud.set_target(null)
    game.hud.set_objective("OWN THE WRECKAGE", "THE COLLAPSE IS NOW TERRAIN // HOLD THE SPACE")
    game.hud.set_objective_progress(0.63)
    game.hud.set_context("PERSISTENT DEBRIS // NEW COVER // NEW ROUTE")
    anchor.global_position = game.structure.global_position + Vector3(0.0, 1.4, 0.0)
    game.camera_rig.set_target(anchor)
    game.camera_rig.yaw = -0.92
    game.camera_rig.pitch = -0.20
    game.camera_rig.distance = 16.0
    game.camera_rig.height = 4.5

func _stage_breach_gate() -> void:
    var gates := get_tree().get_nodes_in_group("breachable")
    if gates.is_empty():
        push_error("CAPTURE_BREACH_GATE_MISSING")
        return
    var gate = gates[0]
    gate.damage_panel(0, 145.0, Vector3(0.15, 0.05, 1.0))
    game.hud.set_machine_mode(true)
    game.hud.set_objective("BREACH THE NORTH ACCESS", "ROUTE CONTROL IS PHYSICAL // THE DOOR BECOMES DEBRIS")
    game.hud.set_objective_progress(1.0)
    game.hud.set_machine_telemetry(0.79, 0.72, 0.86, 0.94, false)
    game.hud.set_context("ACCESS OPEN // DEBRIS REMAINS IN WORLD")
    anchor.global_position = gate.global_position + Vector3(0.0, 1.6, -1.0)
    game.camera_rig.set_target(anchor)
    game.camera_rig.yaw = 0.10
    game.camera_rig.pitch = -0.18
    game.camera_rig.distance = 14.5
    game.camera_rig.height = 3.8

func _release_capture_load() -> void:
    if game.excavator.held_load == null or not is_instance_valid(game.excavator.held_load):
        return
    var load = game.excavator.held_load
    game.excavator.held_load = null
    load.set_held(false)
    load.linear_velocity = Vector3.ZERO
    load.angular_velocity = Vector3.ZERO

func _first_prop():
    for prop in get_tree().get_nodes_in_group("physics_prop"):
        if is_instance_valid(prop) and prop.mass <= 110.0:
            return prop
    return null

func _show_all_enemies(value: bool) -> void:
    for enemy in get_tree().get_nodes_in_group("enemy"):
        enemy.visible = value and enemy != game.excavator.enemy_driver

func _visible_enemies() -> Array[Node]:
    var result: Array[Node] = []
    for enemy in get_tree().get_nodes_in_group("enemy"):
        if enemy.visible:
            result.append(enemy)
    return result

func _settle_frames(count: int) -> void:
    for _i in count:
        await get_tree().process_frame

func _settle_physics_frames(count: int) -> void:
    for _i in count:
        await get_tree().physics_frame

func _capture(filename: String) -> void:
    var image := get_viewport().get_texture().get_image()
    var path := capture_dir.path_join(filename)
    var err := image.save_png(path)
    if err != OK:
        push_error("CAPTURE_FAILED %s err=%s" % [path, err])
        get_tree().quit(2)
        return
    print("CAPTURE_OK ", path, " ", image.get_width(), "x", image.get_height())
