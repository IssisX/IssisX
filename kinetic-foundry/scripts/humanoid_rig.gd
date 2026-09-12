extends Node3D

const GeomUtil = preload("res://scripts/geom.gd")

var player_style := false
var phase := 0.0
var attack_side := 1.0
var attack_mode := 0
var death_blend := 0.0

var pelvis: Node3D
var torso: Node3D
var head_root: Node3D
var arm_l: Node3D
var arm_r: Node3D
var elbow_l: Node3D
var elbow_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var knee_l: Node3D
var knee_r: Node3D

func configure(is_player: bool) -> void:
    player_style = is_player
    _build()

func _build() -> void:
    var cloth := Color(0.18, 0.21, 0.20) if player_style else Color(0.24, 0.275, 0.25)
    var cloth_dark := Color(0.075, 0.082, 0.078)
    var accent := Color(0.48, 0.29, 0.065) if player_style else Color(0.70, 0.48, 0.07)
    var skin := Color(0.62, 0.46, 0.35) if player_style else Color(0.54, 0.41, 0.33)
    var gear := Color(0.10, 0.115, 0.108)

    pelvis = Node3D.new()
    pelvis.position = Vector3(0.0, 0.93, 0.0)
    add_child(pelvis)
    pelvis.add_child(GeomUtil.box_mesh(Vector3(0.62, 0.34, 0.40), cloth_dark, 0.88, 0.02))

    torso = Node3D.new()
    torso.position = Vector3(0.0, 0.25, 0.0)
    pelvis.add_child(torso)
    var torso_mesh := GeomUtil.box_mesh(Vector3(0.82 if player_style else 0.74, 0.82, 0.46), cloth, 0.76, 0.04)
    torso_mesh.position.y = 0.35
    torso.add_child(torso_mesh)
    var chest := GeomUtil.box_mesh(Vector3(0.68, 0.40, 0.075), accent, 0.80, 0.05)
    chest.position = Vector3(0.0, 0.39, -0.265)
    torso.add_child(chest)
    var belt := GeomUtil.box_mesh(Vector3(0.68, 0.12, 0.45), gear, 0.90, 0.08)
    belt.position.y = -0.02
    torso.add_child(belt)

    head_root = Node3D.new()
    head_root.position = Vector3(0.0, 0.88, 0.0)
    torso.add_child(head_root)
    var neck := GeomUtil.cylinder_mesh(0.105, 0.22, skin, 0.82, 0.0)
    neck.position.y = 0.02
    head_root.add_child(neck)
    var head := GeomUtil.sphere_mesh(0.245 if player_style else 0.235, skin)
    head.position.y = 0.26
    head_root.add_child(head)
    var helmet := GeomUtil.box_mesh(
        Vector3(0.52, 0.17, 0.53),
        Color(0.13, 0.15, 0.14) if player_style else Color(0.74, 0.53, 0.09),
        0.72,
        0.06
    )
    helmet.position = Vector3(0.0, 0.42, 0.0)
    head_root.add_child(helmet)
    var brim := GeomUtil.box_mesh(
        Vector3(0.57, 0.055, 0.18),
        Color(0.11, 0.125, 0.12) if player_style else Color(0.64, 0.43, 0.06),
        0.78,
        0.04
    )
    brim.position = Vector3(0.0, 0.34, -0.27)
    head_root.add_child(brim)

    arm_l = _build_arm(torso, -1.0, cloth, gear, skin)
    arm_r = _build_arm(torso, 1.0, cloth, gear, skin)
    elbow_l = arm_l.get_node("Elbow")
    elbow_r = arm_r.get_node("Elbow")
    leg_l = _build_leg(pelvis, -1.0, cloth_dark, gear)
    leg_r = _build_leg(pelvis, 1.0, cloth_dark, gear)
    knee_l = leg_l.get_node("Knee")
    knee_r = leg_r.get_node("Knee")

func _build_arm(parent: Node3D, side: float, cloth: Color, gear: Color, skin: Color) -> Node3D:
    var shoulder := Node3D.new()
    shoulder.name = "ArmL" if side < 0.0 else "ArmR"
    shoulder.position = Vector3(side * 0.47, 0.68, 0.0)
    parent.add_child(shoulder)
    shoulder.add_child(GeomUtil.sphere_mesh(0.17, cloth))
    var upper := GeomUtil.capsule_mesh(0.115, 0.52, cloth)
    upper.position.y = -0.26
    shoulder.add_child(upper)
    var elbow := Node3D.new()
    elbow.name = "Elbow"
    elbow.position.y = -0.51
    shoulder.add_child(elbow)
    elbow.add_child(GeomUtil.sphere_mesh(0.12, gear))
    var forearm := GeomUtil.capsule_mesh(0.105, 0.48, cloth)
    forearm.position.y = -0.24
    elbow.add_child(forearm)
    var hand := GeomUtil.sphere_mesh(0.125, skin)
    hand.position.y = -0.49
    elbow.add_child(hand)
    var glove := GeomUtil.box_mesh(Vector3(0.20, 0.16, 0.18), gear, 0.94, 0.03)
    glove.position = Vector3(0.0, -0.49, -0.055)
    elbow.add_child(glove)
    return shoulder

func _build_leg(parent: Node3D, side: float, cloth: Color, gear: Color) -> Node3D:
    var hip := Node3D.new()
    hip.name = "LegL" if side < 0.0 else "LegR"
    hip.position = Vector3(side * 0.20, -0.05, 0.0)
    parent.add_child(hip)
    var thigh := GeomUtil.capsule_mesh(0.145, 0.55, cloth)
    thigh.position.y = -0.27
    hip.add_child(thigh)
    var knee := Node3D.new()
    knee.name = "Knee"
    knee.position.y = -0.53
    hip.add_child(knee)
    knee.add_child(GeomUtil.sphere_mesh(0.145, gear))
    var shin := GeomUtil.capsule_mesh(0.125, 0.50, cloth)
    shin.position.y = -0.25
    knee.add_child(shin)
    var boot := GeomUtil.box_mesh(Vector3(0.28, 0.18, 0.43), Color(0.045, 0.05, 0.047), 0.98, 0.03)
    boot.position = Vector3(0.0, -0.53, -0.095)
    knee.add_child(boot)
    return hip

func animate(delta: float, planar_speed: float, reference_speed: float, attack_amount: float, hit_amount: float, dead: bool) -> void:
    if pelvis == null:
        return
    var speed_n := clampf(planar_speed / maxf(reference_speed, 0.1), 0.0, 1.35)
    phase += delta * (4.2 + planar_speed * 1.35)
    var stride := sin(phase) * 0.62 * speed_n
    var lift_l := maxf(0.0, -sin(phase)) * 0.72 * speed_n
    var lift_r := maxf(0.0, sin(phase)) * 0.72 * speed_n
    leg_l.rotation = Vector3(stride, 0.0, 0.0)
    leg_r.rotation = Vector3(-stride, 0.0, 0.0)
    knee_l.rotation.x = lift_l
    knee_r.rotation.x = lift_r
    arm_l.rotation = Vector3(-stride * 0.72, 0.0, 0.0)
    arm_r.rotation = Vector3(stride * 0.72, 0.0, 0.0)
    elbow_l.rotation.x = -0.10 - absf(stride) * 0.22
    elbow_r.rotation.x = -0.10 - absf(stride) * 0.22
    pelvis.position.y = 0.93 + absf(sin(phase * 2.0)) * 0.025 * speed_n
    torso.rotation = Vector3(0.0, sin(phase) * 0.055 * speed_n, -sin(phase) * 0.025 * speed_n)
    head_root.rotation = Vector3.ZERO

    if attack_amount > 0.0:
        var action := sin(clampf(attack_amount, 0.0, 1.0) * PI)
        if attack_mode == 1:
            _pose_kick(action)
        elif attack_mode == 2:
            _pose_tackle(action)
        else:
            _pose_punch(action)

    if hit_amount > 0.0:
        torso.rotation.x -= hit_amount * 0.30
        torso.rotation.z += attack_side * hit_amount * 0.16
        head_root.rotation.x = hit_amount * 0.22

    death_blend = move_toward(death_blend, 1.0 if dead else 0.0, delta * (2.8 if dead else 5.0))
    if death_blend > 0.0:
        rotation.z = lerp(0.0, attack_side * 1.32, death_blend)
        rotation.x = lerp(0.0, -0.24, death_blend)
        position.y = -0.12 * death_blend
        leg_l.rotation.x *= 1.0 - death_blend * 0.75
        leg_r.rotation.x *= 1.0 - death_blend * 0.75
    else:
        rotation.z = 0.0
        rotation.x = 0.0
        position.y = 0.0

func _pose_punch(amount: float) -> void:
    torso.rotation.y += attack_side * amount * 0.40
    var attack_arm := arm_r if attack_side > 0.0 else arm_l
    var attack_elbow := elbow_r if attack_side > 0.0 else elbow_l
    attack_arm.rotation.x = -1.05 * amount
    attack_arm.rotation.z = -attack_side * 0.24 * amount
    attack_elbow.rotation.x = -0.42 + 1.12 * amount
    head_root.rotation.y = -attack_side * amount * 0.14

func _pose_kick(amount: float) -> void:
    var kick_leg := leg_r if attack_side > 0.0 else leg_l
    var kick_knee := knee_r if attack_side > 0.0 else knee_l
    var brace_leg := leg_l if attack_side > 0.0 else leg_r
    torso.rotation.x = -0.20 * amount
    torso.rotation.y = -attack_side * 0.22 * amount
    torso.rotation.z = -attack_side * 0.16 * amount
    kick_leg.rotation.x = -1.25 * amount
    kick_leg.rotation.z = attack_side * 0.16 * amount
    kick_knee.rotation.x = 0.22 + 0.72 * (1.0 - amount)
    brace_leg.rotation.x = 0.22 * amount
    arm_l.rotation.x = 0.54 * amount
    arm_r.rotation.x = 0.54 * amount
    arm_l.rotation.z = -0.34 * amount
    arm_r.rotation.z = 0.34 * amount

func _pose_tackle(amount: float) -> void:
    torso.rotation.x = -0.48 * amount
    pelvis.position.y = 0.93 - 0.12 * amount
    arm_l.rotation.x = 0.74 * amount
    arm_r.rotation.x = 0.74 * amount
    arm_l.rotation.z = -0.30 * amount
    arm_r.rotation.z = 0.30 * amount
    elbow_l.rotation.x = -0.52 * amount
    elbow_r.rotation.x = -0.52 * amount
    leg_l.rotation.x = -0.26 * amount
    leg_r.rotation.x = 0.26 * amount
    head_root.rotation.x = 0.18 * amount

func pose_climb(t: float, side: float) -> void:
    if pelvis == null:
        return
    var pull := sin(clampf(t, 0.0, 1.0) * PI)
    phase += 0.13
    torso.rotation = Vector3(-0.18 - pull * 0.18, side * 0.08, -side * 0.10)
    pelvis.position.y = 0.93 + pull * 0.06
    arm_l.rotation = Vector3(-1.35 + sin(phase) * 0.10, 0.0, -0.38)
    arm_r.rotation = Vector3(-1.42 - sin(phase) * 0.10, 0.0, 0.38)
    elbow_l.rotation.x = 0.72 + pull * 0.34
    elbow_r.rotation.x = 0.82 + pull * 0.28
    leg_l.rotation.x = -0.68 + pull * 0.36
    leg_r.rotation.x = 0.44 - pull * 0.18
    knee_l.rotation.x = 1.02
    knee_r.rotation.x = 0.78
    head_root.rotation = Vector3(-0.08, -side * 0.18, 0.0)

func set_attack_side(side: float) -> void:
    attack_side = 1.0 if side >= 0.0 else -1.0

func set_attack_mode(mode: int) -> void:
    attack_mode = clampi(mode, 0, 2)
