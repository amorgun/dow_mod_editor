## Wheel-zoom and drag-pan over the children (attached under $SubViewport).
## Enabled: this control captures all mouse input and the children get none;
## disabled: the children are interactive again and the view transform stays.
class_name PanZoomView extends SubViewportContainer

const MIN_ZOOM := 0.1
const MAX_ZOOM := 16.0

var enabled := false:
	set(val):
		enabled = val
		if is_node_ready():
			viewport.gui_disable_input = val

@onready var viewport: SubViewport = $SubViewport

var _zoom := 1.0
var _offset := Vector2.ZERO
var _dragging := false

func _ready() -> void:
	viewport.gui_disable_input = enabled

func reset() -> void:
	_zoom = 1.0
	_offset = Vector2.ZERO
	_apply()

func _apply() -> void:
	viewport.canvas_transform = Transform2D(0.0, Vector2.ONE * _zoom, 0.0, _offset)

func _zoom_at(point: Vector2, factor: float) -> void:
	var new_zoom := clampf(_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	factor = new_zoom / _zoom
	_offset = point - (point - _offset) * factor
	_zoom = new_zoom
	_apply()

func _gui_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
			_dragging = event.pressed
			accept_event()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(event.position, 1.2)
			accept_event()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(event.position, 1 / 1.2)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_offset += event.relative
		_apply()
		accept_event()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_0 and event.ctrl_pressed and is_visible_in_tree():
		reset()
