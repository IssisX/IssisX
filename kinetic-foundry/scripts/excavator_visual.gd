extends RefCounted

const GeomUtil = preload("res://scripts/geom.gd")

static func build(root: Node3D) -> Dictionary:
    var nodes := {}

    var undercarriage := GeomUtil.box_mesh(Vector3(3.25, 0.46, 4.45), Color(0.09, 0.095, 0.085), 0.94, 0.18)
    undercarriage.position.y = 0.62
    root.add_child(undercarriage)

    for side in [-1.0, 1.0]:
        var track := GeomUtil.box_mesh(Vector3(0.68, 0.82, 4.55), Color(0.055, 0.06, 0.055), 0.98, 0.22)
        track.position = Vector3(side * 1.43, 0.58, 0.0)
        root.add_child(track)
        for shoe_i in 8:
            var shoe := GeomUtil.box_mesh(Vector3(0.78, 0.09, 0.46), Color(0.16, 0.17, 0.15), 0.94, 0.28)
            shoe.position = Vector3(side * 1.43, 1.02, -1.62 + float(shoe_i) * 0.47)
            root.add_child(shoe)

    var turntable := GeomUtil.cylinder_mesh(1.15, 0.44, Color(0.18, 0.19, 0.17), 0.84, 0.30)
    turntable.position.y = 1.10
    root.add_child(turntable)

    var chassis := GeomUtil.box_mesh(Vector3(2.85, 1.16, 3.72), Color(0.80, 0.47, 0.055), 0.66, 0.16)
    chassis.position = Vector3(0.0, 1.65, 0.16)
    root.add_child(chassis)

    var counterweight := GeomUtil.box_mesh(Vector3(2.75, 1.34, 1.22), Color(0.74, 0.40, 0.045), 0.72, 0.18)
    counterweight.position = Vector3(0.0, 1.82, 1.55)
    root.add_child(counterweight)

    var engine_cover := GeomUtil.box_mesh(Vector3(1.18, 1.18, 1.65), Color(0.68, 0.37, 0.045), 0.70, 0.14)
    engine_cover.position = Vector3(0.70, 2.15, 0.58)
    root.add_child(engine_cover)
    nodes.engine_cover = engine_cover

    for grille_i in 5:
        var grille := GeomUtil.box_mesh(Vector3(0.035, 0.72, 0.14), Color(0.11, 0.12, 0.105), 0.86, 0.24)
        grille.position = Vector3(1.305, 1.92, -0.30 + float(grille_i) * 0.28)
        root.add_child(grille)

    var cab_frame := GeomUtil.box_mesh(Vector3(1.46, 1.90, 1.72), Color(0.085, 0.095, 0.09), 0.56, 0.28)
    cab_frame.position = Vector3(-0.66, 2.48, 0.34)
    root.add_child(cab_frame)

    var windshield := GeomUtil.box_mesh(Vector3(1.08, 1.34, 0.055), Color(0.10, 0.20, 0.22), 0.22, 0.40)
    windshield.position = Vector3(-0.66, 2.53, -0.55)
    root.add_child(windshield)
    var side_window := GeomUtil.box_mesh(Vector3(0.055, 1.28, 1.04), Color(0.10, 0.20, 0.22), 0.22, 0.40)
    side_window.position = Vector3(-1.42, 2.54, 0.18)
    root.add_child(side_window)

    var work_light := OmniLight3D.new()
    work_light.position = Vector3(-0.74, 3.47, -0.58)
    work_light.light_color = Color(1.0, 0.72, 0.38)
    work_light.light_energy = 1.8
    work_light.omni_range = 7.5
    root.add_child(work_light)
    nodes.work_light = work_light

    var beacon := GeomUtil.cylinder_mesh(0.12, 0.18, Color(0.98, 0.43, 0.05), 0.34, 0.05)
    beacon.material_override = GeomUtil.emissive_material(Color(0.98, 0.43, 0.05), 2.4, 0.34, 0.05)
    beacon.position = Vector3(-0.70, 3.52, 0.88)
    root.add_child(beacon)

    var boom := Node3D.new()
    boom.position = Vector3(0.62, 2.37, -0.88)
    root.add_child(boom)
    nodes.boom = boom
    boom.add_child(GeomUtil.sphere_mesh(0.42, Color(0.18, 0.19, 0.17)))
    var boom_mesh := GeomUtil.box_mesh(Vector3(0.58, 0.66, 4.72), Color(0.84, 0.49, 0.055), 0.61, 0.14)
    boom_mesh.position.z = -2.15
    boom.add_child(boom_mesh)
    var boom_rod := GeomUtil.capsule_mesh(0.095, 3.55, Color(0.68, 0.69, 0.64))
    boom_rod.rotation.x = PI * 0.5
    boom_rod.position = Vector3(0.42, 0.20, -1.72)
    boom.add_child(boom_rod)

    var stick := Node3D.new()
    stick.position = Vector3(0.0, 0.0, -4.28)
    boom.add_child(stick)
    nodes.stick = stick
    stick.add_child(GeomUtil.sphere_mesh(0.34, Color(0.18, 0.19, 0.17)))
    var stick_mesh := GeomUtil.box_mesh(Vector3(0.46, 0.54, 3.58), Color(0.84, 0.49, 0.055), 0.61, 0.14)
    stick_mesh.position.z = -1.65
    stick.add_child(stick_mesh)
    var stick_rod := GeomUtil.capsule_mesh(0.075, 2.70, Color(0.69, 0.70, 0.66))
    stick_rod.rotation.x = PI * 0.5
    stick_rod.position = Vector3(-0.34, 0.18, -1.28)
    stick.add_child(stick_rod)

    var tool := Node3D.new()
    tool.position = Vector3(0.0, 0.0, -3.28)
    stick.add_child(tool)
    nodes.tool = tool
    var bucket := GeomUtil.box_mesh(Vector3(1.86, 1.12, 1.30), Color(0.24, 0.25, 0.225), 0.90, 0.38)
    bucket.position = Vector3(0.0, -0.12, -0.52)
    tool.add_child(bucket)
    for tooth_i in 4:
        var tooth := GeomUtil.box_mesh(Vector3(0.22, 0.20, 0.54), Color(0.17, 0.18, 0.16), 0.94, 0.42)
        tooth.position = Vector3(-0.66 + float(tooth_i) * 0.44, -0.46, -1.08)
        tooth.rotation.x = -0.22
        tool.add_child(tooth)

    var thumb := Node3D.new()
    thumb.position = Vector3(0.0, 0.38, -0.62)
    tool.add_child(thumb)
    nodes.thumb = thumb
    for side in [-0.56, 0.56]:
        var jaw := GeomUtil.box_mesh(Vector3(0.18, 0.18, 1.10), Color(0.15, 0.16, 0.145), 0.90, 0.40)
        jaw.position = Vector3(side, 0.0, -0.45)
        jaw.rotation.x = 0.42
        thumb.add_child(jaw)

    var grip_anchor := Node3D.new()
    grip_anchor.position = Vector3(0.0, -0.10, -0.82)
    tool.add_child(grip_anchor)
    nodes.grip_anchor = grip_anchor

    var impact_probe := Area3D.new()
    impact_probe.collision_layer = 0
    impact_probe.collision_mask = 4 | 8
    tool.add_child(impact_probe)
    var shape := BoxShape3D.new()
    shape.size = Vector3(2.0, 1.55, 1.95)
    var impact_collision := CollisionShape3D.new()
    impact_collision.shape = shape
    impact_collision.position = Vector3(0.0, -0.10, -0.55)
    impact_probe.add_child(impact_collision)
    nodes.impact_probe = impact_probe

    return nodes
