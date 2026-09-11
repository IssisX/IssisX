class_name StructuralFrame
extends Node3D

var support_health := [100.0, 100.0, 100.0, 100.0]
var supports: Array[StaticBody3D] = []
var deck: RigidBody3D
var collapsed := false

func _ready() -> void:
    add_to_group("structure")
    _build_frame()

func _build_frame() -> void:
    var positions := [
        Vector3(-3.7, 2.3, -2.2),
        Vector3(3.7, 2.3, -2.2),
        Vector3(-3.7, 2.3, 2.2),
        Vector3(3.7, 2.3, 2.2)
    ]
    for i in positions.size():
        var support := _make_support(i, positions[i])
        supports.append(support)
    deck = RigidBody3D.new()
    deck.name = "Deck"
    deck.position = Vector3(0.0, 5.05, 0.0)
    deck.mass = 950.0
    deck.freeze = true
    deck.collision_layer = 8
    deck.collision_mask = 1 | 2 | 4 | 8
    add_child(deck)
    deck.add_child(
        Geom.box_mesh(
            Vector3(9.4, 0.48, 6.0),
            Color(0.22, 0.23, 0.21),
            0.88,
            0.22
        )
    )
    Geom.add_box_collision(
        deck,
        Vector3(9.4, 0.48, 6.0)
    )
    for z in [-2.7, 2.7]:
        var rail := Geom.box_mesh(
            Vector3(9.4, 0.16, 0.16),
            Color(0.48, 0.48, 0.43),
            0.80,
            0.28
        )
        rail.position = Vector3(0.0, 0.72, z)
        deck.add_child(rail)

func _make_support(
        index: int,
        pos: Vector3
) -> StaticBody3D:
    var support := StaticBody3D.new()
    support.name = "Support_%d" % index
    support.position = pos
    support.collision_layer = 8
    support.collision_mask = 1 | 2 | 4
    support.set_meta("support_index", index)
    support.set_script(preload("res://scripts/support.gd"))
    support.set("frame", self)
    add_child(support)
    support.add_child(
        Geom.box_mesh(
            Vector3(0.62, 4.6, 0.62),
            Color(0.43, 0.38, 0.29),
            0.78,
            0.26
        )
    )
    Geom.add_box_collision(
        support,
        Vector3(0.62, 4.6, 0.62)
    )
    return support

func damage_support(
        index: int,
        amount: float,
        direction: Vector3
) -> void:
    if index < 0 or index >= support_health.size():
        return
    if support_health[index] <= 0.0:
        return
    support_health[index] -= amount
    var support := supports[index]
    support.rotation.z += direction.x * amount * 0.0009
    support.rotation.x -= direction.z * amount * 0.0009
    if support_health[index] <= 0.0:
        _break_support(index, direction)
    _evaluate_failure()

func _break_support(index: int, direction: Vector3) -> void:
    var old := supports[index]
    if not is_instance_valid(old):
        return
    var pos := old.global_position
    old.queue_free()
    var debris := RigidBody3D.new()
    debris.position = to_local(pos)
    debris.mass = 180.0
    debris.collision_layer = 8
    debris.collision_mask = 1 | 2 | 4 | 8
    add_child(debris)
    debris.add_child(
        Geom.box_mesh(
            Vector3(0.62, 4.6, 0.62),
            Color(0.34, 0.30, 0.23),
            0.90,
            0.24
        )
    )
    Geom.add_box_collision(
        debris,
        Vector3(0.62, 4.6, 0.62)
    )
    debris.apply_central_impulse(
        direction.normalized() * 2200.0
        + Vector3.UP * 520.0
    )

func _evaluate_failure() -> void:
    if collapsed:
        return
    var alive := 0
    for hp in support_health:
        if hp > 0.0:
            alive += 1
    if alive <= 2:
        collapsed = true
        deck.freeze = false
        deck.apply_torque_impulse(
            Vector3(4200.0, 900.0, -3600.0)
        )
