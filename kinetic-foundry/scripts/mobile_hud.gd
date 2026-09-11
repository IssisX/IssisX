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
var _action_labels: Array[Label] = []
var _mode_label: Label

const STICK_R := 118.0
const DEAD_R := 18.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process_input(true)
    set_process(true)
    _build_labels()

func _build_labels() -> void:
    for i in 3:
        var label := Label.new()
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 23)
        label.add_theme_color_override("font_color", Color(0.97, 0.96, 0.90, 0.96))
        label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.86))
        label.add_theme_constant_override("shadow_offset_x", 2)
        label.add_theme_constant_override("shadow_offset_y", 2)
        add_child(label)
        _action_labels.append(label)

    _mode_label = Label.new()
    _mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _mode_label.position = Vector2(28.0, 24.0)
    _mode_label.size = Vector2(330.0, 52.0)
    _mode_label.add_theme_font_size_override("font_size", 22)
    _mode_label.add_theme_color_override("font_color", Color(0.92, 0.82, 0.55, 0.94))
    _mode_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
    _mode_label.add_theme_constant_override("shadow_offset_x", 2)
    _mode_label.add_theme_constant_override("shadow_offset_y", 2)
    add_child(_mode_label)
    _refresh_labels()

func set_machine_mode(enabled: bool) -> void:
    _machine_mode = enabled
    _refresh_labels()

func _refresh_labels() -> void:
    if _action_labels.size() < 3:
        return
    if _machine_mode:
        _action_labels[0].text = "SMASH"
        _action_labels[1].text = "CURL"
        _action_labels[2].text = "EXIT"
        _mode_label.text = "EXCAVATOR CONTROL"
    else:
        _action_labels[0].text = "HIT"
        _action_labels[1].text = "GRAB"
        _action_labels[2].text = "USE"
        _mode_label.text = "ON FOOT"

func _process(_delta: float) -> void:
    _view_size = get_viewport_rect().size
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
        if delta.length() < DEAD_R:
            move_axis = Vector2.ZERO
        else:
            move_axis = delta.limit_length(STICK_R) / STICK_R
    elif event.index == _look_touch:
        look_accum += event.relative

func _try_action(pos: Vector2) -> bool:
    var attack := _button_rect(0)
    var grab := _button_rect(1)
    var use := _button_rect(2)
    if attack.has_point(pos):
        attack_pulse = true
        smash_held = true
        return true
    if grab.has_point(pos):
        grab_pulse = true
        return true
    if use.has_point(pos):
        use_pulse = true
        return true
    return false

func _button_rect(index: int) -> Rect2:
    var size := Vector2(138.0, 138.0)
    var pad := 34.0
    var x := _view_size.x - size.x - pad
    var y := _view_size.y - size.y - pad
    if index == 1:
        x -= size.x + 24.0
    elif index == 2:
        y -= size.y + 24.0
    return Rect2(Vector2(x, y), size)

func _draw() -> void:
    if _move_touch >= 0:
        draw_circle(
            _move_origin,
            STICK_R,
            Color(0.07, 0.085, 0.09, 0.50)
        )
        draw_arc(
            _move_origin,
            STICK_R,
            0.0,
            TAU,
            48,
            Color(0.80, 0.66, 0.34, 0.74),
            4.0
        )
        draw_circle(
            _move_origin + move_axis * STICK_R,
            48.0,
            Color(0.84, 0.78, 0.62, 0.78)
        )
    _draw_button(0, Color(0.68, 0.16, 0.08, 0.66))
    _draw_button(1, Color(0.76, 0.43, 0.075, 0.64))
    _draw_button(2, Color(0.12, 0.37, 0.42, 0.64))

func _draw_button(index: int, color: Color) -> void:
    var rect := _button_rect(index)
    var center := rect.get_center()
    var radius := rect.size.x * 0.5
    draw_circle(center, radius, Color(0.025, 0.03, 0.03, 0.68))
    draw_circle(center, radius - 7.0, color)
    draw_arc(
        center,
        radius - 3.0,
        0.0,
        TAU,
        48,
        Color(0.88, 0.79, 0.58, 0.72),
        3.0
    )
