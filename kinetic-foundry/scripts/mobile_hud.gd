class_name MobileHud
extends Control

var move_axis := Vector2.ZERO
var look_accum := Vector2.ZERO
var attack_pulse := false
var grab_pulse := false
var use_pulse := false
var smash_held := false

var _move_touch := -1
var _look_touch := -1
var _move_origin := Vector2.ZERO
var _move_pos := Vector2.ZERO
var _view_size := Vector2(1920.0, 1080.0)
var _machine_mode := false
var _health_ratio := 1.0
var _damage_flash := 0.0
var _target
var _context_text := "POWER // COMBAT // MACHINES"
var _objective_title := "BREAK THE YARD CREW"
var _objective_detail := "CUT THE CREW DOWN UNTIL THE MACHINE IS EXPOSED"
var _objective_progress := 0.0
var _machine_integrity := 1.0
var _machine_hydraulics := 1.0
var _machine_tracks := 1.0
var _machine_force := 0.0
var _machine_holding := false

var _action_labels: Array[Label] = []
var _mode_label: Label
var _title_label: Label
var _context_label: Label
var _objective_title_label: Label
var _objective_detail_label: Label

const STICK_R := 105.0
const DEAD_R := 18.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process_input(true)
    set_process(true)
    _build_labels()

func _label(size_px: int, color: Color) -> Label:
    var label := Label.new()
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", size_px)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.88))
    label.add_theme_constant_override("shadow_offset_x", 2)
    label.add_theme_constant_override("shadow_offset_y", 2)
    return label

func _build_labels() -> void:
    _title_label = _label(21, Color(0.95, 0.78, 0.39, 0.98))
    _title_label.text = "KINETIC FOUNDRY"
    add_child(_title_label)
    _mode_label = _label(16, Color(0.76, 0.80, 0.77, 0.94))
    add_child(_mode_label)
    _context_label = _label(17, Color(0.89, 0.88, 0.81, 0.92))
    _context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(_context_label)
    _objective_title_label = _label(18, Color(0.96, 0.70, 0.25, 0.98))
    _objective_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(_objective_title_label)
    _objective_detail_label = _label(13, Color(0.77, 0.79, 0.75, 0.93))
    _objective_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(_objective_detail_label)
    for _i in 3:
        var label := _label(18, Color(0.98, 0.96, 0.88, 0.98))
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        add_child(label)
        _action_labels.append(label)
    _refresh_labels()

func set_machine_mode(enabled: bool) -> void:
    _machine_mode = enabled
    _refresh_labels()

func set_health(value: float) -> void:
    _health_ratio = clampf(value, 0.0, 1.0)

func set_target(node) -> void:
    _target = node

func set_context(text: String) -> void:
    _context_text = text

func set_objective(title: String, detail: String) -> void:
    _objective_title = title
    _objective_detail = detail

func set_objective_progress(value: float) -> void:
    _objective_progress = clampf(value, 0.0, 1.0)

func set_machine_telemetry(integrity: float, hydraulics: float, tracks: float, force_ratio: float, holding: bool) -> void:
    _machine_integrity = clampf(integrity, 0.0, 1.0)
    _machine_hydraulics = clampf(hydraulics, 0.0, 1.0)
    _machine_tracks = clampf(tracks, 0.0, 1.0)
    _machine_force = clampf(force_ratio, 0.0, 1.0)
    _machine_holding = holding
    if _machine_mode and _action_labels.size() >= 2:
        _action_labels[1].text = "RELEASE" if holding else "CLAMP"

func flash_damage() -> void:
    _damage_flash = 1.0

func _refresh_labels() -> void:
    if _action_labels.size() < 3:
        return
    if _machine_mode:
        _action_labels[0].text = "SMASH"
        _action_labels[1].text = "RELEASE" if _machine_holding else "CLAMP"
        _action_labels[2].text = "EXIT"
        _mode_label.text = "EXCAVATOR // LOAD + FORCE AUTHORITY"
    else:
        _action_labels[0].text = "HIT"
        _action_labels[1].text = "GRAB"
        _action_labels[2].text = "USE"
        _mode_label.text = "ON FOOT // ADAPTIVE LOCK"

func _process(delta: float) -> void:
    _view_size = get_viewport_rect().size
    _damage_flash = maxf(0.0, _damage_flash - delta * 3.8)
    _title_label.position = Vector2(42.0, 30.0)
    _title_label.size = Vector2(290.0, 28.0)
    _mode_label.position = Vector2(42.0, 58.0)
    _mode_label.size = Vector2(370.0, 24.0)
    _context_label.text = _context_text
    _context_label.position = Vector2(_view_size.x * 0.5 - 260.0, _view_size.y - 58.0)
    _context_label.size = Vector2(520.0, 32.0)
    _objective_title_label.text = _objective_title
    _objective_title_label.position = Vector2(_view_size.x * 0.5 - 260.0, 25.0)
    _objective_title_label.size = Vector2(520.0, 28.0)
    _objective_detail_label.text = _objective_detail
    _objective_detail_label.position = Vector2(_view_size.x * 0.5 - 330.0, 52.0)
    _objective_detail_label.size = Vector2(660.0, 24.0)
    for i in mini(3, _action_labels.size()):
        var rect := _button_rect(i)
        _action_labels[i].position = rect.position
        _action_labels[i].size = rect.size
    queue_redraw()

func consume_look() -> Vector2:
    var out := look_accum
    look_accum = Vector2.ZERO
    return out

func consume_attack() -> bool:
    var out := attack_pulse
    attack_pulse = false
    return out

func consume_grab() -> bool:
    var out := grab_pulse
    grab_pulse = false
    return out

func consume_use() -> bool:
    var out := use_pulse
    use_pulse = false
    return out

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        _touch(event)
    elif event is InputEventScreenDrag:
        _drag(event)

func _touch(event: InputEventScreenTouch) -> void:
    if event.pressed:
        if _try_action(event.position):
            return
        if event.position.x < _view_size.x * 0.46:
            if _move_touch < 0:
                _move_touch = event.index
                _move_origin = event.position
                _move_pos = event.position
                move_axis = Vector2.ZERO
            return
        if _look_touch < 0:
            _look_touch = event.index
    else:
        if event.index == _move_touch:
            _move_touch = -1
            move_axis = Vector2.ZERO
        if event.index == _look_touch:
            _look_touch = -1
        smash_held = false

func _drag(event: InputEventScreenDrag) -> void:
    if event.index == _move_touch:
        _move_pos = event.position
        var delta := _move_pos - _move_origin
        move_axis = Vector2.ZERO if delta.length() < DEAD_R else delta.limit_length(STICK_R) / STICK_R
    elif event.index == _look_touch:
        look_accum += event.relative

func _try_action(pos: Vector2) -> bool:
    if _button_rect(0).has_point(pos):
        attack_pulse = true
        smash_held = true
        return true
    if _button_rect(1).has_point(pos):
        grab_pulse = true
        return true
    if _button_rect(2).has_point(pos):
        use_pulse = true
        return true
    return false

func _button_rect(index: int) -> Rect2:
    var size := Vector2(154.0, 104.0)
    var pad := 30.0
    var x := _view_size.x - size.x - pad
    var y := _view_size.y - size.y - pad
    if index == 1:
        x -= size.x + 18.0
    elif index == 2:
        y -= size.y + 16.0
        x -= 28.0
    return Rect2(Vector2(x, y), size)

func _draw() -> void:
    _draw_status_panel()
    _draw_objective_panel()
    if _machine_mode:
        _draw_machine_panel()
    _draw_move_zone()
    _draw_action_button(0, Color(0.74, 0.20, 0.075, 0.86))
    _draw_action_button(1, Color(0.76, 0.48, 0.08, 0.82))
    _draw_action_button(2, Color(0.10, 0.42, 0.48, 0.82))
    _draw_target_bracket()
    if _damage_flash > 0.0:
        draw_rect(Rect2(Vector2.ZERO, _view_size), Color(0.70, 0.045, 0.02, 0.10 * _damage_flash), false, 12.0)

func _draw_status_panel() -> void:
    var panel := Rect2(Vector2(26.0, 20.0), Vector2(350.0, 94.0))
    _rounded(panel, Color(0.018, 0.024, 0.025, 0.80), Color(0.47, 0.39, 0.22, 0.72), 2.0)
    var bar_bg := Rect2(Vector2(42.0, 88.0), Vector2(272.0, 10.0))
    draw_rect(bar_bg, Color(0.08, 0.09, 0.085, 0.90))
    var hp_color := Color(0.82, 0.53, 0.10, 0.94) if _health_ratio >= 0.34 else Color(0.82, 0.16, 0.06, 0.96)
    draw_rect(Rect2(bar_bg.position, Vector2(bar_bg.size.x * _health_ratio, bar_bg.size.y)), hp_color)
    draw_string(ThemeDB.fallback_font, Vector2(342.0, 98.0), "%d%%" % int(_health_ratio * 100.0), HORIZONTAL_ALIGNMENT_RIGHT, 30.0, 13, Color(0.88, 0.86, 0.78, 0.90))

func _draw_objective_panel() -> void:
    var x := _view_size.x * 0.5 - 350.0
    var panel := Rect2(Vector2(x, 16.0), Vector2(700.0, 82.0))
    _rounded(panel, Color(0.015, 0.020, 0.020, 0.68), Color(0.35, 0.32, 0.22, 0.62), 1.5)
    var bg := Rect2(Vector2(x + 22.0, 78.0), Vector2(656.0, 5.0))
    draw_rect(bg, Color(0.07, 0.075, 0.07, 0.86))
    draw_rect(Rect2(bg.position, Vector2(bg.size.x * _objective_progress, bg.size.y)), Color(0.88, 0.55, 0.10, 0.92))

func _draw_machine_panel() -> void:
    var panel := Rect2(Vector2(26.0, 130.0), Vector2(350.0, 128.0))
    _rounded(panel, Color(0.018, 0.024, 0.025, 0.80), Color(0.46, 0.36, 0.16, 0.70), 2.0)
    draw_string(ThemeDB.fallback_font, Vector2(42.0, 153.0), "MACHINE STATE", HORIZONTAL_ALIGNMENT_LEFT, 160.0, 14, Color(0.93, 0.72, 0.28))
    _meter(Vector2(42.0, 168.0), "INT", _machine_integrity, Color(0.84, 0.43, 0.08))
    _meter(Vector2(42.0, 193.0), "HYD", _machine_hydraulics, Color(0.18, 0.58, 0.65))
    _meter(Vector2(42.0, 218.0), "TRK", _machine_tracks, Color(0.62, 0.60, 0.49))
    _meter(Vector2(42.0, 243.0), "FRC", _machine_force, Color(0.94, 0.64, 0.12))
    var clamp_text := "CLAMP: LOAD" if _machine_holding else "CLAMP: OPEN"
    draw_string(ThemeDB.fallback_font, Vector2(257.0, 153.0), clamp_text, HORIZONTAL_ALIGNMENT_LEFT, 86.0, 12, Color(0.83, 0.84, 0.78))

func _meter(pos: Vector2, name: String, value: float, color: Color) -> void:
    draw_string(ThemeDB.fallback_font, pos + Vector2(0.0, 11.0), name, HORIZONTAL_ALIGNMENT_LEFT, 36.0, 11, Color(0.76, 0.78, 0.73))
    var bg := Rect2(pos + Vector2(42.0, 2.0), Vector2(245.0, 8.0))
    draw_rect(bg, Color(0.07, 0.075, 0.07, 0.92))
    draw_rect(Rect2(bg.position, Vector2(bg.size.x * value, bg.size.y)), color)

func _draw_move_zone() -> void:
    var center := Vector2(142.0, _view_size.y - 142.0)
    draw_circle(center, 82.0, Color(0.02, 0.027, 0.028, 0.46))
    draw_arc(center, 82.0, 0.0, TAU, 48, Color(0.55, 0.48, 0.30, 0.46), 2.5)
    draw_arc(center, 44.0, 0.0, TAU, 40, Color(0.63, 0.65, 0.59, 0.26), 2.0)
    if _move_touch >= 0:
        draw_circle(_move_origin, STICK_R, Color(0.03, 0.04, 0.04, 0.48))
        draw_arc(_move_origin, STICK_R, 0.0, TAU, 48, Color(0.80, 0.66, 0.34, 0.76), 3.5)
        draw_circle(_move_origin + move_axis * STICK_R, 42.0, Color(0.84, 0.78, 0.62, 0.82))

func _draw_action_button(index: int, accent: Color) -> void:
    var rect := _button_rect(index)
    var visual := Rect2(rect.position + Vector2(4.0, 17.0), Vector2(rect.size.x - 8.0, rect.size.y - 34.0))
    _rounded(visual, Color(0.018, 0.024, 0.025, 0.78), Color(accent.r, accent.g, accent.b, 0.82), 2.5)
    draw_rect(Rect2(visual.position, Vector2(6.0, visual.size.y)), accent)

func _rounded(rect: Rect2, fill: Color, border: Color, border_width: float) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.set_border_width_all(int(border_width))
    style.corner_radius_top_left = 12
    style.corner_radius_top_right = 12
    style.corner_radius_bottom_left = 12
    style.corner_radius_bottom_right = 12
    draw_style_box(style, rect)

func _draw_target_bracket() -> void:
    if _target == null or not is_instance_valid(_target) or not (_target is Node3D):
        return
    var camera := get_viewport().get_camera_3d()
    if camera == null or camera.is_position_behind(_target.global_position + Vector3.UP * 1.25):
        return
    var p := camera.unproject_position(_target.global_position + Vector3.UP * 1.25)
    var r := 30.0
    var c := Color(0.94, 0.60, 0.14, 0.88)
    draw_line(p + Vector2(-r, -r), p + Vector2(-r * 0.35, -r), c, 3.0)
    draw_line(p + Vector2(-r, -r), p + Vector2(-r, -r * 0.35), c, 3.0)
    draw_line(p + Vector2(r, -r), p + Vector2(r * 0.35, -r), c, 3.0)
    draw_line(p + Vector2(r, -r), p + Vector2(r, -r * 0.35), c, 3.0)
    draw_line(p + Vector2(-r, r), p + Vector2(-r * 0.35, r), c, 3.0)
    draw_line(p + Vector2(-r, r), p + Vector2(-r, r * 0.35), c, 3.0)
    draw_line(p + Vector2(r, r), p + Vector2(r * 0.35, r), c, 3.0)
    draw_line(p + Vector2(r, r), p + Vector2(r, r * 0.35), c, 3.0)
