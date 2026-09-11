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

const STICK_R := 118.0
const DEAD_R := 18.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process_input(true)
    set_process(true)

func _process(_delta: float) -> void:
    _view_size = get_viewport_rect().size
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
            Color(0.12, 0.14, 0.15, 0.42)
        )
        draw_circle(
            _move_origin + move_axis * STICK_R,
            48.0,
            Color(0.82, 0.84, 0.78, 0.72)
        )
    _draw_button(0, Color(0.72, 0.18, 0.10, 0.64))
    _draw_button(1, Color(0.82, 0.50, 0.10, 0.60))
    _draw_button(2, Color(0.22, 0.48, 0.55, 0.60))

func _draw_button(index: int, color: Color) -> void:
    var rect := _button_rect(index)
    draw_circle(rect.get_center(), rect.size.x * 0.5, color)
