extends Node

var character_tier := 0
var equipment_tier := 0
var completed_missions := 0
var upgrade_points := 0
var _bound_missions: Dictionary = {}
var _player

const SAVE_PATH := "user://kinetic_foundry_progress.cfg"

func _ready() -> void:
    _load_state()
    get_tree().node_added.connect(_on_node_added)
    call_deferred("_scan_scene")

func _scan_scene() -> void:
    await get_tree().process_frame
    for node in get_tree().get_nodes_in_group("player"):
        _bind_player(node)
    var scene := get_tree().current_scene
    if scene != null:
        _scan_for_mission(scene)

func _on_node_added(node: Node) -> void:
    call_deferred("_inspect_node", node)

func _inspect_node(node: Node) -> void:
    if not is_instance_valid(node):
        return
    if node.is_in_group("player"):
        _bind_player(node)
    if node.has_signal("mission_complete"):
        _bind_mission(node)

func _scan_for_mission(node: Node) -> void:
    if node.has_signal("mission_complete"):
        _bind_mission(node)
    for child in node.get_children():
        _scan_for_mission(child)

func _bind_player(node) -> void:
    _player = node
    _apply_player_progression()

func _bind_mission(node) -> void:
    var id := node.get_instance_id()
    if _bound_missions.has(id):
        return
    _bound_missions[id] = true
    node.mission_complete.connect(_on_mission_complete)

func _on_mission_complete() -> void:
    completed_missions += 1
    upgrade_points += 2
    if character_tier <= equipment_tier:
        character_tier += 1
    else:
        equipment_tier += 1
    _apply_player_progression()
    _save_state()
    var hud := _find_hud()
    if hud != null:
        hud.set_context("UPGRADE ACQUIRED // CHARACTER %d // EQUIPMENT %d" % [character_tier, equipment_tier])

func _apply_player_progression() -> void:
    if _player == null or not is_instance_valid(_player):
        return
    var base_max_health := 180.0
    var base_speed := 7.4
    var base_sprint := 10.2
    _player.max_health = base_max_health + equipment_tier * 24.0 + character_tier * 8.0
    _player.health = minf(_player.health + equipment_tier * 10.0, _player.max_health)
    _player.speed = base_speed + character_tier * 0.28
    _player.sprint_speed = base_sprint + character_tier * 0.42
    _player.set_meta("character_tier", character_tier)
    _player.set_meta("equipment_tier", equipment_tier)

func _find_hud():
    var scene := get_tree().current_scene
    if scene == null:
        return null
    var value = scene.get("hud")
    return value

func _save_state() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("progress", "character_tier", character_tier)
    cfg.set_value("progress", "equipment_tier", equipment_tier)
    cfg.set_value("progress", "completed_missions", completed_missions)
    cfg.set_value("progress", "upgrade_points", upgrade_points)
    cfg.save(SAVE_PATH)

func _load_state() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) != OK:
        return
    character_tier = int(cfg.get_value("progress", "character_tier", 0))
    equipment_tier = int(cfg.get_value("progress", "equipment_tier", 0))
    completed_missions = int(cfg.get_value("progress", "completed_missions", 0))
    upgrade_points = int(cfg.get_value("progress", "upgrade_points", 0))
