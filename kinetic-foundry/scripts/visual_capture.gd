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
    await get_tree().process_frame
    _freeze_gameplay()

    # 01 - establish the complete industrial yard and scale hierarchy.
    anchor.global_position = Vector3(1.0, 0.0, -2.0)
    game.camera_rig.set_target(anchor)
    game.camera_rig.yaw = 0.66
    game.camera_rig.pitch = -0.36
    game.camera_rig.distance = 27.0
    game.camera_rig.height = 8.0
    await _settle_frames(18)
    await _capture("01_yard_overview.png")

    # 02 - readable human-scale combat staging.
    game.player.visible = true
    game.player.global_position = Vector3(-7.0, 1.1, 8.0)
    game.player.rotation.y = -0.35
    var visible_enemies := _visible_enemies()
    var combat_positions := [
        Vector3(-4.8, 1.0, 5.7),
        Vector3(-8.8, 1.0, 4.8),
        Vector3(-2.8, 1.0, 8.8)
    ]
    for i in mini(visible_enemies.size(), combat_positions.size()):
        visible_enemies[i].global_position = combat_positions[i]
        visible_enemies[i].look_at(game.player.global_position, Vector3.UP)
    game.camera_rig.set_target(game.player)
    game.camera_rig.yaw = 0.42
    game.camera_rig.pitch = -0.24
    game.camera_rig.distance = 9.8
    game.camera_rig.height = 3.2
    await _settle_frames(16)
    await _capture("02_combat_staging.png")

    # 03 - machine authority: player-controlled excavator with articulated tool.
    game.player.visible = false
    for enemy in get_tree().get_nodes_in_group("enemy"):
        enemy.visible = false
    game.excavator.enemy_driver = null
    game.excavator.player_driver = game.player
    game.excavator.arm_yaw = -0.34
    game.excavator.boom_angle = -0.62
    game.excavator.stick_angle = 0.76
    game.excavator.tool_angle = -0.48
    game.excavator._apply_arm_pose()
    game.camera_rig.set_target(game.excavator)
    game.camera_rig.yaw = -0.72
    game.camera_rig.pitch = -0.30
    game.camera_rig.distance = 14.5
    game.camera_rig.height = 4.8
    await _settle_frames(18)
    await _capture("03_excavator_operation.png")

    # 04 - structural consequence: remove two supports, then let gravity resolve.
    game.structure.damage_support(0, 125.0, Vector3(1.0, 0.0, 0.25))
    game.structure.damage_support(2, 125.0, Vector3(1.0, 0.0, -0.20))
    anchor.global_position = game.structure.global_position + Vector3(0.0, 1.7, 0.0)
    game.camera_rig.set_target(anchor)
    game.camera_rig.yaw = -0.88
    game.camera_rig.pitch = -0.26
    game.camera_rig.distance = 14.0
    game.camera_rig.height = 4.6
    await _settle_physics_frames(42)
    await _settle_frames(8)
    await _capture("04_structure_failure.png")

    print("CAPTURE_SUITE_OK dir=", capture_dir)
    get_tree().quit(0)

func _freeze_gameplay() -> void:
    game.player.process_mode = Node.PROCESS_MODE_DISABLED
    game.excavator.process_mode = Node.PROCESS_MODE_DISABLED
    for enemy in get_tree().get_nodes_in_group("enemy"):
        enemy.process_mode = Node.PROCESS_MODE_DISABLED

func _visible_enemies() -> Array[Node]:
    var result: Array[Node] = []
    for enemy in get_tree().get_nodes_in_group("enemy"):
        if enemy.visible:
            result.append(enemy)
    return result

func _settle_frames(count: int) -> void:
    for _i in count:
        await get_tree().process_frame
        await RenderingServer.frame_post_draw

func _settle_physics_frames(count: int) -> void:
    for _i in count:
        await get_tree().physics_frame

func _capture(filename: String) -> void:
    await RenderingServer.frame_post_draw
    var image := get_viewport().get_texture().get_image()
    var path := capture_dir.path_join(filename)
    var err := image.save_png(path)
    if err != OK:
        push_error("CAPTURE_FAILED %s err=%s" % [path, err])
        get_tree().quit(2)
        return
    print("CAPTURE_OK ", path, " ", image.get_width(), "x", image.get_height())
