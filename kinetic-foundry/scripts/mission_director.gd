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

const TITLES := [
    "BREAK THE YARD CREW",
    "TAKE THE EXCAVATOR",
    "DROP THE TRANSFER PLATFORM",
    "OWN THE WRECKAGE"
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
        var living := 0
        for enemy in get_tree().get_nodes_in_group("enemy"):
            if is_instance_valid(enemy) and not enemy.dead and enemy.visible:
                living += 1
        var initial := 5.0
        var progress := clampf((initial - float(living)) / initial, 0.0, 1.0)
        if hud != null and hud.has_method("set_objective_progress"):
            hud.set_objective_progress(progress)
        if living <= 3:
            stage = 1
            _publish()
    elif stage == 3:
        _hold_timer += delta
        var progress := clampf(_hold_timer / 6.0, 0.0, 1.0)
        if hud != null and hud.has_method("set_objective_progress"):
            hud.set_objective_progress(progress)
        if _hold_timer >= 6.0:
            _complete = true
            if hud != null:
                if hud.has_method("set_objective"):
                    hud.set_objective("YARD SECURED", "THE FOUNDRY JUST CHANGED HANDS")
                if hud.has_method("set_context"):
                    hud.set_context("MISSION COMPLETE // INDUSTRIAL AUTHORITY ACQUIRED")
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
    var title := TITLES[stage]
    var detail := ""
    match stage:
        0:
            detail = "CUT THE CREW DOWN UNTIL THE MACHINE IS EXPOSED"
        1:
            detail = "CLOSE ON THE EXCAVATOR AND RIP THE OPERATOR OUT"
        2:
            detail = "USE REAL BUCKET FORCE ON THE MARKED SUPPORTS"
        3:
            detail = "STAY IN THE COLLAPSE ZONE AND KEEP CONTROL"
    if hud != null and hud.has_method("set_objective"):
        hud.set_objective(title, detail)
    if hud != null and hud.has_method("set_objective_progress"):
        hud.set_objective_progress(0.0)
    objective_changed.emit(title, detail, 0.0)
