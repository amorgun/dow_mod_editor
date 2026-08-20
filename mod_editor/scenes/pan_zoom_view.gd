## Wheel-zoom and middle-mouse drag-pan over the children (attached under
## $SubViewport); always active, other buttons reach the children normally.
class_name PanZoomView extends SubViewportContainer

const MIN_ZOOM := 0.1
const MAX_ZOOM := 16.0

## When > 0, the viewport renders 2D content at this constant pixel height
## (size_2d_override) and stretches to fit, so authored font and pixel sizes
## come out correct at any control size.
var virtual_height := 0.0:
	set(val):
		virtual_height = val
		if is_node_ready():
			_apply_override()

@onready var viewport: SubViewport = $SubViewport

var _zoom := 1.0
var _offset := Vector2.ZERO
var _dragging := false

func _ready() -> void:
	_apply_override()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_apply_override()

func _apply_override() -> void:
	if virtual_height <= 0 or size.y <= 0:
		viewport.size_2d_override = Vector2i.ZERO
		return
	viewport.size_2d_override = Vector2i(size * (virtual_height / size.y))
	viewport.size_2d_override_stretch = true

## Container-local pixels -> viewport 2D canvas units.
func _to_canvas(p: Vector2) -> Vector2:
	if virtual_height <= 0 or size.y <= 0:
		return p
	return p * (virtual_height / size.y)

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
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed
			accept_event()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(_to_canvas(event.position), 1.2)
			accept_event()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(_to_canvas(event.position), 1 / 1.2)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		if not (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE):
			_dragging = false
			return
		_offset += _to_canvas(event.relative)
		_apply()
		accept_event()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_reset") and is_visible_in_tree():
		reset()
