extends Node3D

const PlayerScene = preload("res://scripts/player.gd")
const EnemyScene = preload("res://scripts/enemy.gd")
const ExcavatorScene = preload("res://scripts/excavator.gd")
const StructureScene = preload("res://scripts/structure.gd")
const CameraRigScene = preload("res://scripts/camera_rig.gd")
const HudScene = preload("res://scripts/mobile_hud.gd")
const YardScene = preload("res://scripts/industrial_yard.gd")
const HazardFieldScene = preload("res://scripts/hazard_field.gd")
const MissionDirectorScene = preload("res://scripts/mission_director.gd")
const CaptureRunnerScene = preload("res://scripts/visual_capture.gd")

var hud
var camera_rig
var player
var excavator
var structure
var yard
var hazards
var mission

func _ready() -> void:
    _build_environment()
    _build_world()
    _build_gameplay()
    _build_mission()
    if OS.get_environment("KF_CAPTURE") == "1":
        print("CAPTURE_STAGE activation")
        var capture_runner := CaptureRunnerScene.new()
        add_child(capture_runner)
        capture_runner.begin(self)

func _build_environment() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.026, 0.034, 0.038)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.29, 0.32, 0.33)
    env.ambient_light_energy = 0.56
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.fog_enabled = true
    env.fog_light_color = Color(0.11, 0.13, 0.135)
    env.fog_density = 0.009
    world.environment = env
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
    sun.light_color = Color(0.92, 0.84, 0.70)
    sun.light_energy = 1.75
    sun.shadow_enabled = true
    add_child(sun)

func _build_world() -> void:
    yard = YardScene.new()
    add_child(yard)
    hazards = HazardFieldScene.new()
    add_child(hazards)

func _build_gameplay() -> void:
    hud = HudScene.new()
    add_child(hud)
    camera_rig = CameraRigScene.new()
    add_child(camera_rig)

    player = PlayerScene.new()
    player.position = Vector3(-10.0, 0.03, 13.0)
    add_child(player)
    player.configure(hud, camera_rig)
    player.request_machine_entry.connect(_on_player_use)
    camera_rig.set_target(player)

    excavator = ExcavatorScene.new()
    excavator.position = Vector3(4.0, -0.17, -3.0)
    excavator.rotation.y = 0.42
    add_child(excavator)
    excavator.configure(hud, camera_rig)
    excavator.player_entered.connect(_on_machine_entered)
    excavator.player_exited.connect(_on_machine_exited)
    excavator.machine_disabled.connect(_on_machine_disabled)

    var operator = _spawn_enemy(Vector3(4.0, 0.03, -3.0))
    excavator.set_enemy_driver(operator)
    _spawn_enemy(Vector3(-3.0, 0.03, 5.0))
    _spawn_enemy(Vector3(1.0, 0.03, 10.0))
    _spawn_enemy(Vector3(8.0, 0.03, 7.0))
    _spawn_enemy(Vector3(-11.5, 0.03, -1.0))
    _spawn_enemy(Vector3(14.0, 0.03, 11.5))

    structure = StructureScene.new()
    structure.position = Vector3(11.0, 0.0, -14.0)
    add_child(structure)

func _build_mission() -> void:
    mission = MissionDirectorScene.new()
    add_child(mission)
    mission.configure(player, excavator, structure, hud)

func _spawn_enemy(pos: Vector3):
    var enemy = EnemyScene.new()
    enemy.position = pos
    add_child(enemy)
    enemy.set_target(player)
    return enemy

func _retarget_enemies(target_node) -> void:
    for enemy in get_tree().get_nodes_in_group("enemy"):
        if is_instance_valid(enemy) and not enemy.dead:
            enemy.set_target(target_node)

func _on_player_use(user) -> void:
    excavator.try_enter(user)

func _on_machine_entered(machine) -> void:
    camera_rig.set_target(machine)
    camera_rig.distance = 13.4
    camera_rig.height = 5.0
    _retarget_enemies(machine)

func _on_machine_exited(_machine) -> void:
    camera_rig.set_target(player)
    camera_rig.distance = 9.8
    camera_rig.height = 3.2
    _retarget_enemies(player)

func _on_machine_disabled(machine) -> void:
    if machine.player_driver != null:
        machine.exit_player()
    hud.set_context("EXCAVATOR DISABLED // RETURN TO FOOT CONTROL")
    _retarget_enemies(player)
