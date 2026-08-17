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

var _is_dragging: bool = false
var _is_resizing: bool = false
var _resize_dir: int = ResizeEdge.NONE 

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_interaction()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
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
		if not _is_dragging and not _is_resizing:
			_update_mouse_cursor(_get_resize_direction(event.position))
		elif _is_dragging:
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
		
	mouse_default_cursor_shape = Control.CURSOR_ARROW

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

func _handle_drag(relative_motion: Vector2) -> void:
	var parent := get_parent_control()
	if not parent or parent.size.x == 0 or parent.size.y == 0:
		return

	var delta := relative_motion / parent.size
	anchor_left += delta.x
	anchor_right += delta.x
	anchor_top += delta.y
	anchor_bottom += delta.y
	interactive_dragged.emit(position)

func _handle_resize(relative_motion: Vector2) -> void:
	var parent := get_parent_control()
	if not parent or parent.size.x == 0 or parent.size.y == 0:
		return

	# Handle X Axis Resizing
	if _resize_dir & ResizeEdge.RIGHT:
		var allowed_motion := relative_motion.x
		if size.x + allowed_motion < min_window_size.x:
			allowed_motion = min_window_size.x - size.x
		anchor_right += allowed_motion / parent.size.x
		
	elif _resize_dir & ResizeEdge.LEFT:
		var allowed_motion := relative_motion.x
		if size.x - allowed_motion < min_window_size.x:
			allowed_motion = size.x - min_window_size.x
		anchor_left += allowed_motion / parent.size.x

	# Handle Y Axis Resizing
	if _resize_dir & ResizeEdge.BOTTOM:
		var allowed_motion := relative_motion.y
		if size.y + allowed_motion < min_window_size.y:
			allowed_motion = min_window_size.y - size.y
		anchor_bottom += allowed_motion / parent.size.y
		
	elif _resize_dir & ResizeEdge.TOP:
		var allowed_motion := relative_motion.y
		if size.y - allowed_motion < min_window_size.y:
			allowed_motion = size.y - min_window_size.y
		anchor_top += allowed_motion / parent.size.y

	interactive_resized.emit(size)

func _update_mouse_cursor(dir: int) -> void:
	var target_shape: Control.CursorShape = Control.CURSOR_ARROW
	
	if dir == (ResizeEdge.TOP | ResizeEdge.LEFT) or dir == (ResizeEdge.BOTTOM | ResizeEdge.RIGHT):
		target_shape = Control.CURSOR_FDIAGSIZE
	elif dir == (ResizeEdge.TOP | ResizeEdge.RIGHT) or dir == (ResizeEdge.BOTTOM | ResizeEdge.LEFT):
		target_shape = Control.CURSOR_BDIAGSIZE
	elif (dir & ResizeEdge.LEFT) != 0 or (dir & ResizeEdge.RIGHT) != 0:
		target_shape = Control.CURSOR_HSIZE
	elif (dir & ResizeEdge.TOP) != 0 or (dir & ResizeEdge.BOTTOM) != 0:
		target_shape = Control.CURSOR_VSIZE
	else:
		target_shape = Control.CURSOR_ARROW
	if mouse_default_cursor_shape != target_shape:
		mouse_default_cursor_shape = target_shape
