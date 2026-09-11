class_name StructuralFrame
extends Node3D

const GeomUtil = preload("res://scripts/geom.gd")
const SupportScript = preload("res://scripts/support.gd")

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
        GeomUtil.box_mesh(
            Vector3(9.4, 0.48, 6.0),
            Color(0.18, 0.19, 0.175),
            0.90,
            0.24
        )
    )
    GeomUtil.add_box_collision(deck, Vector3(9.4, 0.48, 6.0))

    for x in [-4.15, -2.05, 0.0, 2.05, 4.15]:
        var girder := GeomUtil.box_mesh(
            Vector3(0.28, 0.58, 6.1),
            Color(0.29, 0.27, 0.20),
            0.82,
            0.30
        )
        girder.position = Vector3(x, -0.34, 0.0)
        deck.add_child(girder)

    for z in [-2.72, 2.72]:
        var rail_top := GeomUtil.box_mesh(
            Vector3(9.4, 0.13, 0.13),
            Color(0.70, 0.47, 0.08),
            0.78,
            0.22
        )
        rail_top.position = Vector3(0.0, 1.06, z)
        deck.add_child(rail_top)
        var rail_mid := GeomUtil.box_mesh(
            Vector3(9.4, 0.09, 0.09),
            Color(0.47, 0.48, 0.42),
            0.80,
            0.24
        )
        rail_mid.position = Vector3(0.0, 0.62, z)
        deck.add_child(rail_mid)
        for x in [-4.4, -2.2, 0.0, 2.2, 4.4]:
            var post := GeomUtil.box_mesh(
                Vector3(0.12, 1.16, 0.12),
                Color(0.47, 0.48, 0.42),
                0.80,
                0.24
            )
            post.position = Vector3(x, 0.58, z)
            deck.add_child(post)

    for stripe_i in 10:
        var stripe := GeomUtil.box_mesh(
            Vector3(0.62, 0.03, 0.40),
            Color(0.76, 0.54, 0.10) if stripe_i % 2 == 0 else Color(0.07, 0.075, 0.07),
            0.84,
            0.06
        )
        stripe.position = Vector3(-4.15 + float(stripe_i) * 0.92, 0.255, -2.80)
        stripe.rotation.y = 0.55
        deck.add_child(stripe)

    _build_cross_braces()

func _build_cross_braces() -> void:
    for z in [-2.22, 2.22]:
        for direction in [-1.0, 1.0]:
            var brace := GeomUtil.box_mesh(
                Vector3(0.22, 5.45, 0.22),
                Color(0.33, 0.29, 0.19),
                0.82,
                0.25
            )
            brace.position = Vector3(0.0, 2.6, z)
            brace.rotation.z = direction * 0.94
            add_child(brace)

func _make_support(index: int, pos: Vector3) -> StaticBody3D:
    var support := StaticBody3D.new()
    support.name = "Support_%d" % index
    support.position = pos
    support.collision_layer = 8
    support.collision_mask = 1 | 2 | 4
    support.set_meta("support_index", index)
    support.set_script(SupportScript)
    support.set("frame", self)
    add_child(support)

    support.add_child(
        GeomUtil.box_mesh(
            Vector3(0.72, 4.6, 0.72),
            Color(0.39, 0.33, 0.20),
            0.80,
            0.30
        )
    )
    GeomUtil.add_box_collision(support, Vector3(0.72, 4.6, 0.72))

    var foot := GeomUtil.box_mesh(
        Vector3(1.28, 0.32, 1.28),
        Color(0.20, 0.205, 0.19),
        0.88,
        0.24
    )
    foot.position.y = -2.14
    support.add_child(foot)

    for plate_y in [-1.15, 0.15, 1.45]:
        var plate := GeomUtil.box_mesh(
            Vector3(0.83, 0.16, 0.83),
            Color(0.64, 0.43, 0.08),
            0.74,
            0.20
        )
        plate.position.y = plate_y
        support.add_child(plate)
    return support

func damage_support(index: int, amount: float, direction: Vector3) -> void:
    if index < 0 or index >= support_health.size():
        return
    if support_health[index] <= 0.0:
        return
    support_health[index] -= amount
    var support := supports[index]
    if is_instance_valid(support):
        support.rotation.z += direction.x * amount * 0.0009
        support.rotation.x -= direction.z * amount * 0.0009
    if support_health[index] <= 0.0:
        _break_support(index, direction)
    _apply_pre_failure_pose()
    _evaluate_failure()

func _apply_pre_failure_pose() -> void:
    if collapsed or deck == null:
        return
    var left_capacity: float = maxf(support_health[0], 0.0) + maxf(support_health[2], 0.0)
    var right_capacity: float = maxf(support_health[1], 0.0) + maxf(support_health[3], 0.0)
    var north_capacity: float = maxf(support_health[0], 0.0) + maxf(support_health[1], 0.0)
    var south_capacity: float = maxf(support_health[2], 0.0) + maxf(support_health[3], 0.0)
    var roll := clamp((right_capacity - left_capacity) / 200.0, -1.0, 1.0) * 0.075
    var pitch := clamp((south_capacity - north_capacity) / 200.0, -1.0, 1.0) * 0.060
    var total_capacity: float = left_capacity + right_capacity
    var sag := clamp((400.0 - total_capacity) / 400.0, 0.0, 1.0) * 0.18
    deck.rotation.x = pitch
    deck.rotation.z = roll
    deck.position.y = 5.05 - sag

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
        GeomUtil.box_mesh(
            Vector3(0.72, 4.6, 0.72),
            Color(0.31, 0.27, 0.18),
            0.92,
            0.30
        )
    )
    GeomUtil.add_box_collision(debris, Vector3(0.72, 4.6, 0.72))
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
        deck.apply_torque_impulse(Vector3(4200.0, 900.0, -3600.0))
        deck.apply_central_impulse(Vector3(220.0, -180.0, -120.0))
