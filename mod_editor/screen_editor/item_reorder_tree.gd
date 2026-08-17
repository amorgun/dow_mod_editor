class_name ItemReorderTree extends Tree

signal reordered(from_index: int, to_index: int)

var reorder_enabled := true

func _get_drag_data(at_position: Vector2) -> Variant:
	if not reorder_enabled:
		return null
	var dragged_item := get_item_at_position(at_position)
	if not dragged_item:
		return null
	var preview := Label.new()
	preview.text = dragged_item.get_text(0)
	set_drag_preview(preview)
	drop_mode_flags = DropModeFlags.DROP_MODE_INBETWEEN
	return dragged_item

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return data is TreeItem and data.get_tree() == self and get_item_at_position(at_position) != null

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var moved_item: TreeItem = data
	var target_item := get_item_at_position(at_position)
	var drop_section := get_drop_section_at_position(at_position)
	drop_mode_flags = DropModeFlags.DROP_MODE_DISABLED
	if target_item == null or moved_item == target_item:
		return
	var from_index := moved_item.get_index()
	var to_index := target_item.get_index() + (1 if drop_section == 1 else 0)
	if from_index < to_index:
		to_index -= 1
	if from_index != to_index:
		reordered.emit(from_index, to_index)
