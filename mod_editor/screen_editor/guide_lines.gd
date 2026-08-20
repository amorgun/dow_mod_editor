## Draws the screen's ruler guides over the canvas and makes them draggable.
class_name GuideLines extends Control

signal guide_dragged(index: int, new_position: float)

const COLOR := Color(0.2, 0.8, 0.9, 0.7)

var screen: UiScreen = null
## Half-width in px of the drag area around a line, from the editor config.
var grab_margin := 4.0
## Snap grid step in px; 0 disables snapping.
var snap_px := 0.0

var _drag_index := -1
var _drag_position := 0.0

func _draw() -> void:
	if screen == null:
		return
	for i in len(screen.guides):
		var g = screen.guides[i]
		if g is not Dictionary:
			continue
		var pos := _drag_position if i == _drag_index else float(g.get("position", 0.0))
		if bool(g.get("horizontal", false)):
			draw_line(Vector2(0, pos * size.y), Vector2(size.x, pos * size.y), COLOR)
		else:
			draw_line(Vector2(pos * size.x, 0), Vector2(pos * size.x, size.y), COLOR)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

## Only the drag areas around the lines count as part of the control, so
## clicks elsewhere fall through to the screen widgets for picking.
func _has_point(point: Vector2) -> bool:
	return _drag_index >= 0 or _guide_at(point) >= 0

func _guide_at(point: Vector2) -> int:
	if screen == null:
		return -1
	for i in len(screen.guides):
		var g = screen.guides[i]
		if g is not Dictionary:
			continue
		var pos := float(g.get("position", 0.0))
		var dist := absf(point.y - pos * size.y) if bool(g.get("horizontal", false)) else absf(point.x - pos * size.x)
		if dist <= grab_margin:
			return i
	return -1

func _fraction(point: Vector2, horizontal: bool) -> float:
	var px := clampf(point.y if horizontal else point.x, 0.0, size.y if horizontal else size.x)
	if snap_px > 0.0:
		px = snappedf(px, snap_px)
	return px / (size.y if horizontal else size.x)

func _gui_input(event: InputEvent) -> void:
	if screen == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var index := _guide_at(event.position)
			if index >= 0:
				_drag_index = index
				_drag_position = float(screen.guides[index].get("position", 0.0))
				accept_event()
		elif _drag_index >= 0:
			var index := _drag_index
			var final := _drag_position
			_drag_index = -1
			queue_redraw()
			guide_dragged.emit(index, final)
			accept_event()
	elif event is InputEventMouseMotion:
		if _drag_index >= 0:
			var horizontal: bool = bool(screen.guides[_drag_index].get("horizontal", false))
			_drag_position = _fraction(event.position, horizontal)
			queue_redraw()
			accept_event()
		else:
			var index := _guide_at(event.position)
			var shape := Control.CURSOR_ARROW
			if index >= 0:
				shape = Control.CURSOR_VSIZE if bool(screen.guides[index].get("horizontal", false)) else Control.CURSOR_HSIZE
			if mouse_default_cursor_shape != shape:
				mouse_default_cursor_shape = shape
