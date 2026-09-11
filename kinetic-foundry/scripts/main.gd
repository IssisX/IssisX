extends Node3D

const GeomUtil = preload("res://scripts/geom.gd")
const PlayerScene = preload("res://scripts/player.gd")
const EnemyScene = preload("res://scripts/enemy.gd")
const ExcavatorScene = preload("res://scripts/excavator.gd")
const StructureScene = preload("res://scripts/structure.gd")
const CameraRigScene = preload("res://scripts/camera_rig.gd")
const HudScene = preload("res://scripts/mobile_hud.gd")
const CaptureRunnerScene = preload("res://scripts/visual_capture.gd")

var hud
var camera_rig
var player
var excavator
var structure

func _ready() -> void:
    _build_environment()
    _build_yard()
    _build_gameplay()
    if OS.get_environment("KF_CAPTURE") == "1":
        print("CAPTURE_STAGE activation")
        var capture_runner := CaptureRunnerScene.new()
        add_child(capture_runner)
        capture_runner.begin(self)

func _build_environment() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.055, 0.065, 0.070)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.36, 0.39, 0.40)
    env.ambient_light_energy = 0.72
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.fog_enabled = true
    env.fog_light_color = Color(0.16, 0.18, 0.18)
    env.fog_density = 0.008
    world.environment = env
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-54.0, -34.0, 0.0)
    sun.light_energy = 1.85
    sun.shadow_enabled = true
    add_child(sun)

func _build_yard() -> void:
    GeomUtil.static_box(
        self,
        "Ground",
        Vector3(0.0, -0.50, 0.0),
        Vector3(72.0, 1.0, 72.0),
        Color(0.105, 0.115, 0.115)
    )
    for x in [-26.0, 26.0]:
        GeomUtil.static_box(
            self,
            "Wall",
            Vector3(x, 4.0, 0.0),
            Vector3(1.0, 8.0, 64.0),
            Color(0.19, 0.20, 0.19)
        )
    for z in [-28.0, 28.0]:
        GeomUtil.static_box(
            self,
            "Wall",
            Vector3(0.0, 4.0, z),
            Vector3(52.0, 8.0, 1.0),
            Color(0.19, 0.20, 0.19)
        )
    for i in 8:
        var x := -18.0 + float(i % 4) * 6.0
        var z := -19.0 + float(i / 4) * 7.0
        GeomUtil.static_box(
            self,
            "Cargo",
            Vector3(x, 1.1, z),
            Vector3(4.4, 2.2, 2.4),
            Color(0.24, 0.26, 0.24)
        )

func _build_gameplay() -> void:
    hud = HudScene.new()
    add_child(hud)
    camera_rig = CameraRigScene.new()
    add_child(camera_rig)
    player = PlayerScene.new()
    player.position = Vector3(-10.0, 1.1, 13.0)
    add_child(player)
    player.configure(hud, camera_rig)
    player.request_machine_entry.connect(_on_player_use)
    camera_rig.set_target(player)
    excavator = ExcavatorScene.new()
    excavator.position = Vector3(4.0, 0.8, -3.0)
    excavator.rotation.y = 0.42
    add_child(excavator)
    excavator.configure(hud, camera_rig)
    excavator.player_entered.connect(_on_machine_entered)
    excavator.player_exited.connect(_on_machine_exited)
    var operator = _spawn_enemy(Vector3(4.0, 1.0, -3.0))
    excavator.set_enemy_driver(operator)
    _spawn_enemy(Vector3(-3.0, 1.0, 5.0))
    _spawn_enemy(Vector3(1.0, 1.0, 10.0))
    _spawn_enemy(Vector3(8.0, 1.0, 7.0))
    structure = StructureScene.new()
    structure.position = Vector3(11.0, 0.0, -14.0)
    add_child(structure)

func _spawn_enemy(pos: Vector3):
    var enemy = EnemyScene.new()
    enemy.position = pos
    add_child(enemy)
    enemy.set_target(player)
    return enemy

func _on_player_use(user) -> void:
    excavator.try_enter(user)

func _on_machine_entered(machine) -> void:
    camera_rig.set_target(machine)
    camera_rig.distance = 12.5
    camera_rig.height = 4.7

func _on_machine_exited(_machine) -> void:
    camera_rig.set_target(player)
    camera_rig.distance = 9.4
    camera_rig.height = 3.1
