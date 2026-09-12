extends Node

signal objective_changed(title, detail, progress)
signal mission_complete

var stage := 0
var player
var excavator
var structure
var hud
var _hold_timer := 0.0
var _complete := false

const TITLES: Array[String] = [
    "BREAK THE YARD CREW",
    "TAKE THE EXCAVATOR",
    "DROP THE TRANSFER PLATFORM",
    "OWN THE WRECKAGE",
    "BREACH THE NORTH ACCESS"
]

func configure(player_node, machine_node, structure_node, hud_node) -> void:
    player = player_node
    excavator = machine_node
    structure = structure_node
    hud = hud_node
    if excavator != null:
        excavator.player_entered.connect(_on_machine_entered)
    if structure != null and structure.has_signal("structure_collapsed"):
        structure.structure_collapsed.connect(_on_structure_collapsed)
    _publish()
    set_process(true)

func _process(delta: float) -> void:
    if _complete:
        return

    if stage == 0:
        var living: int = 0
        for enemy in get_tree().get_nodes_in_group("enemy"):
            if is_instance_valid(enemy) and not enemy.dead and enemy.visible:
                living += 1
        var initial: float = 5.0
        var progress: float = clampf((initial - float(living)) / initial, 0.0, 1.0)
        _set_progress(progress)
        if living <= 3:
            stage = 1
            _publish()

    elif stage == 3:
        _hold_timer += delta
        var progress: float = clampf(_hold_timer / 4.5, 0.0, 1.0)
        _set_progress(progress)
        if _hold_timer >= 4.5:
            stage = 4
            _publish()

    elif stage == 4:
        var gates: Array[Node] = get_tree().get_nodes_in_group("breachable")
        if gates.is_empty():
            return
        var gate: Node = gates[0]
        var left_ratio: float = 1.0
        var right_ratio: float = 1.0
        var health = gate.get("panel_health")
        if health is Array and health.size() >= 2:
            left_ratio = clampf(float(health[0]) / 120.0, 0.0, 1.0)
            right_ratio = clampf(float(health[1]) / 120.0, 0.0, 1.0)
        _set_progress(1.0 - minf(left_ratio, right_ratio))
        if bool(gate.get("breached")):
            _finish_mission()

func _set_progress(value: float) -> void:
    if hud != null and hud.has_method("set_objective_progress"):
        hud.set_objective_progress(value)

func _finish_mission() -> void:
    if _complete:
        return
    _complete = true
    if hud != null:
        if hud.has_method("set_objective"):
            hud.set_objective("YARD SECURED", "ACCESS OPEN // INDUSTRIAL CONTROL ACQUIRED")
        if hud.has_method("set_objective_progress"):
            hud.set_objective_progress(1.0)
        if hud.has_method("set_context"):
            hud.set_context("MISSION COMPLETE // THE FOUNDRY CHANGED HANDS")
    mission_complete.emit()

func _on_machine_entered(_machine) -> void:
    if stage <= 1:
        stage = 2
        _publish()

func _on_structure_collapsed() -> void:
    if stage <= 2:
        stage = 3
        _hold_timer = 0.0
        _publish()

func _publish() -> void:
    if _complete:
        return
    var title: String = TITLES[stage]
    var detail: String = ""
    match stage:
        0:
            detail = "CUT THE CREW DOWN UNTIL THE MACHINE IS EXPOSED"
        1:
            detail = "CLOSE ON THE EXCAVATOR // LATCH // RIP THE OPERATOR OUT"
        2:
            detail = "USE REAL BUCKET VELOCITY ON THE MARKED SUPPORTS"
        3:
            detail = "HOLD THE COLLAPSE ZONE WHILE THE WORLD SETTLES"
        4:
            detail = "DRIVE NORTH // BREAK A GATE LEAF // TURN THE DOOR INTO DEBRIS"
    if hud != null and hud.has_method("set_objective"):
        hud.set_objective(title, detail)
    _set_progress(0.0)
    objective_changed.emit(title, detail, 0.0)
