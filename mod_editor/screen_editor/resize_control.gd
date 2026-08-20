class_name ResizerControl extends Control

signal drag_started
signal drag_ended
signal interactive_dragged(new_position: Vector2)

signal resize_started
signal resize_ended
signal interactive_resized(new_size: Vector2)

enum ResizeEdge {
	NONE = 0,
	LEFT = 1 << 0,
	RIGHT = 1 << 1,
	TOP = 1 << 2,
	BOTTOM = 1 << 3,
}

@export var grab_margin: int = 8
@export var min_window_size: Vector2 = Vector2(50, 50)
## Snap grid step in parent-space pixels; 0 disables snapping.
@export var snap_step: float = 0.0
## Accumulated motion below this many px is a click, not a drag/resize.
@export var drag_threshold: float = 4.0

## Parent-space x positions of vertical guide lines; within snap_step they win over the grid.
var snap_lines_x: Array[float] = []
## Parent-space y positions of horizontal guide lines.
var snap_lines_y: Array[float] = []
## Parent-space point the snap grid is anchored at (the screen content origin,
## which is inset from the canvas in fixed-ratio view).
var snap_origin := Vector2.ZERO

var _is_dragging: bool = false
var _is_resizing: bool = false
var _resize_dir: int = ResizeEdge.NONE
var _start_rect := Rect2()
var _acc := Vector2.ZERO
var _past_threshold := false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_interaction()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_rect = Rect2(position, size)
				_acc = Vector2.ZERO
				_past_threshold = false
				var dir := _get_resize_direction(event.position)
				if dir != ResizeEdge.NONE:
					_is_resizing = true
					_resize_dir = dir
					resize_started.emit()
				else:
					_is_dragging = true
					drag_started.emit()

				# Prevent the click from passing through to controls underneath
				accept_event()
			else:
				cancel_interaction()

	elif event is InputEventMouseMotion:
		if _is_dragging:
			_handle_drag(event.relative)
			accept_event()
		elif _is_resizing:
			_handle_resize(event.relative)
			accept_event()

func cancel_interaction() -> void:
	if _is_dragging:
		_is_dragging = false
		drag_ended.emit()

	if _is_resizing:
		_is_resizing = false
		_resize_dir = ResizeEdge.NONE
		resize_ended.emit()

## The resize band extends grab_margin outside the box as well.
func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).grow(grab_margin).has_point(point)

func _get_resize_direction(local_mouse_pos: Vector2) -> int:
	var dir: int = ResizeEdge.NONE

	if local_mouse_pos.x < grab_margin:
		dir |= ResizeEdge.LEFT
	elif local_mouse_pos.x > size.x - grab_margin:
		dir |= ResizeEdge.RIGHT

	if local_mouse_pos.y < grab_margin:
		dir |= ResizeEdge.TOP
	elif local_mouse_pos.y > size.y - grab_margin:
		dir |= ResizeEdge.BOTTOM

	return dir

## Snaps a single edge coordinate: the nearest guide line within snap_step
## wins, otherwise the grid. Identity when snapping is off.
func _snap_edge(value: float, lines: Array[float], origin: float) -> float:
	if snap_step <= 0.0:
		return value
	var nearest := INF
	for line in lines:
		if absf(line - value) < absf(nearest - value):
			nearest = line
	if absf(nearest - value) <= snap_step:
		return nearest
	return origin + snappedf(value - origin, snap_step)

## Snaps a dragged span along one axis; returns the leading coordinate.
## A guide line within snap_step of either edge wins over the grid; otherwise
## the edge needing the smaller grid adjustment decides.
func _snap_span(lead: float, span: float, lines: Array[float], origin: float) -> float:
	if snap_step <= 0.0:
		return lead
	var guide := INF
	for line in lines:
		for candidate in [line, line - span]:
			if absf(candidate - lead) < absf(guide - lead):
				guide = candidate
	if absf(guide - lead) <= snap_step:
		return guide
	var by_lead := origin + snappedf(lead - origin, snap_step)
	var by_trail := origin + snappedf(lead + span - origin, snap_step) - span
	return by_trail if absf(by_trail - lead) < absf(by_lead - lead) else by_lead

func _past_drag_threshold(relative_motion: Vector2) -> bool:
	_acc += relative_motion
	if not _past_threshold and _acc.length() >= drag_threshold:
		_past_threshold = true
	return _past_threshold

func _handle_drag(relative_motion: Vector2) -> void:
	if not _past_drag_threshold(relative_motion):
		return
	var target := _start_rect.position + _acc
	position = Vector2(
		_snap_span(target.x, _start_rect.size.x, snap_lines_x, snap_origin.x),
		_snap_span(target.y, _start_rect.size.y, snap_lines_y, snap_origin.y))
	interactive_dragged.emit(position)

func _handle_resize(relative_motion: Vector2) -> void:
	if not _past_drag_threshold(relative_motion):
		return
	var rect := _start_rect

	if _resize_dir & ResizeEdge.RIGHT:
		var right := _snap_edge(_start_rect.end.x + _acc.x, snap_lines_x, snap_origin.x)
		rect.size.x = maxf(right - rect.position.x, min_window_size.x)
	elif _resize_dir & ResizeEdge.LEFT:
		var left := _snap_edge(_start_rect.position.x + _acc.x, snap_lines_x, snap_origin.x)
		left = minf(left, _start_rect.end.x - min_window_size.x)
		rect.position.x = left
		rect.size.x = _start_rect.end.x - left

	if _resize_dir & ResizeEdge.BOTTOM:
		var bottom := _snap_edge(_start_rect.end.y + _acc.y, snap_lines_y, snap_origin.y)
		rect.size.y = maxf(bottom - rect.position.y, min_window_size.y)
	elif _resize_dir & ResizeEdge.TOP:
		var top := _snap_edge(_start_rect.position.y + _acc.y, snap_lines_y, snap_origin.y)
		top = minf(top, _start_rect.end.y - min_window_size.y)
		rect.position.y = top
		rect.size.y = _start_rect.end.y - top

	position = rect.position
	size = rect.size
	interactive_resized.emit(size)
