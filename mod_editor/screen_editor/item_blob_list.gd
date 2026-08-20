## Vertical list of draggable "blob" cards; the selected blob gets a white border.
class_name ItemBlobList extends ScrollContainer

signal item_selected()
signal reordered(from_index: int, to_index: int)

var reorder_enabled := true
var selected := -1

var _box: VBoxContainer
var _style_normal := StyleBoxFlat.new()
var _style_selected: StyleBoxFlat

class Blob extends PanelContainer:
	var list: ItemBlobList
	var label: Label

	func _init(list_: ItemBlobList, text: String, states: Variant) -> void:
		list = list_
		var box := HBoxContainer.new()
		add_child(box)
		label = Label.new()
		label.text = text
		label.clip_text = true
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(label)
		if states is Array:
			# fixed-width per-state cells so the blobs line up like a table
			for s in PropRow.STATE_NAMES:
				var cell := Label.new()
				cell.text = s[0]
				cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				cell.custom_minimum_size.x = 14
				cell.modulate = Color(1, 1, 1, 1.0 if s in states else 0.2)
				box.add_child(cell)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			list.select(get_index())
			accept_event()

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if not list.reorder_enabled:
			return null
		var preview := Label.new()
		preview.text = label.text
		set_drag_preview(preview)
		return self

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return data is Blob and data.list == list

	func _drop_data(at_position: Vector2, data: Variant) -> void:
		list._drop_blob(data, get_index() + (1 if at_position.y > size.y / 2 else 0))

func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_box)
	_style_normal.bg_color = Color(0.17, 0.19, 0.23)
	_style_normal.set_corner_radius_all(6)
	# constant border width so selection does not shift the layout
	_style_normal.set_border_width_all(2)
	_style_normal.border_color = Color.TRANSPARENT
	_style_normal.set_content_margin_all(6)
	_style_selected = _style_normal.duplicate()
	_style_selected.border_color = Color.WHITE

func clear() -> void:
	selected = -1
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()

func add_item(text: String, states: Variant = null) -> void:
	var blob := Blob.new(self, text, states)
	blob.add_theme_stylebox_override("panel", _style_normal)
	_box.add_child(blob)

func select(index: int) -> void:
	if index < 0 or index >= _box.get_child_count():
		return
	if selected >= 0 and selected < _box.get_child_count():
		_box.get_child(selected).add_theme_stylebox_override("panel", _style_normal)
	selected = index
	_box.get_child(index).add_theme_stylebox_override("panel", _style_selected)
	item_selected.emit()

func _drop_blob(blob: Blob, to_index: int) -> void:
	var from_index := blob.get_index()
	if from_index < to_index:
		to_index -= 1
	if from_index != to_index:
		reordered.emit(from_index, to_index)

## Drops below the last blob move the item to the end.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Blob and data.list == self

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_drop_blob(data, _box.get_child_count())
