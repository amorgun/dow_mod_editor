class_name WidgetTree extends Tree

signal select_widget(widget: UiScreen.Widget)
signal copy_requested(widget: UiScreen.Widget)
signal paste_requested(target: UiScreen.Widget, target_item: TreeItem)
signal delete_requested(widget: UiScreen.Widget, item: TreeItem)

enum MenuId {
	COPY,
	PASTE,
	DELETE,
}

var undo_redo: UndoRedo = null
var _name_before := ""
var _menu: PopupMenu

var _icon_visible: ImageTexture = ImageTexture.create_from_image(Settings.data.pload_image("data:art/ui/textures/GuiVisibilityVisible.svg"))
var _icon_hidden: ImageTexture = ImageTexture.create_from_image(Settings.data.pload_image("data:art/ui/textures/GuiVisibilityHidden.svg"))
var _icon_widget: ImageTexture = ImageTexture.create_from_image(Settings.data.pload_image("data:art/ui/textures/Widget.svg"))
var _icon_widget_slot: ImageTexture = ImageTexture.create_from_image(Settings.data.pload_image("data:art/ui/textures/WidgetSlot.svg"))


func _ready() -> void:
	set_column_expand(1, false)
	set_column_custom_minimum_width(1, 8)
	_menu = PopupMenu.new()
	_menu.add_item("Copy", MenuId.COPY)
	_menu.add_item("Paste", MenuId.PASTE)
	_menu.add_item("Delete", MenuId.DELETE)
	_menu.id_pressed.connect(_on_menu_id_pressed)
	add_child(_menu)

func create_widget_node(widget: UiScreen.Widget, root: TreeItem, slot: int = -1, style_owned: bool = false) -> TreeItem:
	var it := create_item(root)
	it.set_meta("widget", widget)
	it.set_meta("slot", slot)
	it.set_meta("style_owned", style_owned)
	it.add_button(1, _icon_visible, -1, false, "Toggle Visibility")
	sync_item(it)
	return it

func _get_widget(item: TreeItem) -> UiScreen.Widget:
	return item.get_meta("widget")

func _is_slotted(item: TreeItem) -> bool:
	return item.get_meta("slot", -1) != -1

func _is_style_owned(item: TreeItem) -> bool:
	return item.get_meta("style_owned", false)

func sync_item(item: TreeItem) -> void:
	var widget := _get_widget(item)
	item.set_text(0, widget.full_name)
	item.set_icon(0, _icon_widget_slot if _is_slotted(item) else _icon_widget)
	item.set_meta("visible", widget.visible)
	item.set_button(1, 0, _icon_visible if widget.visible else _icon_hidden)

func find_item(widget: UiScreen.Widget, from: TreeItem = get_root()) -> TreeItem:
	if from == null:
		return null
	if from.has_meta("widget") and _get_widget(from) == widget:
		return from
	for c in from.get_children():
		var found := find_item(widget, c)
		if found != null:
			return found
	return null

func config_index(parent_item: TreeItem, tree_index: int) -> int:
	var res := 0
	for i in mini(tree_index, parent_item.get_child_count()):
		if not _is_slotted(parent_item.get_child(i)):
			res += 1
	return res

func child_count(parent_item: TreeItem) -> int:
	return config_index(parent_item, parent_item.get_child_count())

func _get_drag_data(at_position: Vector2) -> Variant:
	var dragged_item := get_item_at_position(at_position)
	if not dragged_item or _is_style_owned(dragged_item):
		return null
	var preview = Label.new()
	preview.text = dragged_item.get_text(0)
	set_drag_preview(preview)
	drop_mode_flags = DropModeFlags.DROP_MODE_INBETWEEN | DropModeFlags.DROP_MODE_ON_ITEM
	return dragged_item

func _drop_parent(at_position: Vector2) -> TreeItem:
	var target_item := get_item_at_position(at_position)
	if target_item == null:
		return null
	if get_drop_section_at_position(at_position) == 0:
		return target_item
	return target_item.get_parent()

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if data is not TreeItem:
		return false
	var target_item := get_item_at_position(at_position)
	if target_item == null:
		drop_mode_flags = 0
		return false
	var new_parent := _drop_parent(at_position)
	if new_parent == null or _is_style_owned(new_parent):
		drop_mode_flags = 0
		return false
	if _is_slotted(data) and new_parent != data.get_parent():
		drop_mode_flags = 0
		return false
	drop_mode_flags = DropModeFlags.DROP_MODE_INBETWEEN | DropModeFlags.DROP_MODE_ON_ITEM
	return true

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var moved_item: TreeItem = data
	var target_item := get_item_at_position(at_position)
	var drop_section := get_drop_section_at_position(at_position)

	var old_index := moved_item.get_index()
	var old_parent := moved_item.get_parent()
	var new_index := -1
	var new_parent: TreeItem = null
	if moved_item != target_item:
		match drop_section:
			-1:
				new_parent = target_item.get_parent()
				new_index = target_item.get_index()
			0:
				var c := target_item
				while  c != null:
					if c == moved_item:
						return
					c = c.get_parent()
				new_parent = target_item
				new_index = 0
			1:
				new_parent = target_item.get_parent()
				new_index = target_item.get_index() + 1
		if new_parent == old_parent and old_index < new_index:
			new_index -= 1
		if _is_slotted(moved_item):
			# reordering among slots is cosmetic: tree only, no config or node change
			_move_tree_item(moved_item, new_parent, new_index)
			drop_mode_flags = DropModeFlags.DROP_MODE_DISABLED
			return
		if not new_parent.has_meta("widget") or not old_parent.has_meta("widget"):
			drop_mode_flags = DropModeFlags.DROP_MODE_DISABLED
			return
		new_index = clampi(new_index, 0, child_count(new_parent))
		var old_config_index := config_index(old_parent, old_index)
		var new_config_index := config_index(new_parent, new_index)
		undo_redo.create_action("Move widget")
		# lambdas capture widgets only: TreeItems are recreated by undo of other
		# actions, so they are re-resolved via find_item at execution time
		var widget := _get_widget(moved_item)
		var old_parent_widget := _get_widget(old_parent)
		var new_parent_widget := _get_widget(new_parent)
		undo_redo.add_do_method(func ():
			_move_item(widget, new_parent_widget, new_index, new_config_index)
			widget.emit_signal("update")
		)
		undo_redo.add_undo_method(func ():
			_move_item(widget, old_parent_widget, old_index, old_config_index)
			widget.emit_signal("update")
		)
		undo_redo.commit_action()
	drop_mode_flags = DropModeFlags.DROP_MODE_DISABLED

func _move_tree_item(item: TreeItem, new_parent: TreeItem, new_index: int) -> void:
	item.get_parent().remove_child(item)
	new_parent.add_child(item)
	if new_index + 1 != new_parent.get_child_count():
		item.move_before(new_parent.get_child(new_index))

func _move_item(item_widget: UiScreen.Widget, new_parent_widget: UiScreen.Widget, new_index: int, new_config_index: int) -> void:
	var item := find_item(item_widget)
	var new_parent := find_item(new_parent_widget)
	var old_parent_widget := item_widget.parent_widget
	_move_tree_item(item, new_parent, new_index)
	old_parent_widget.children_root.remove_child(item_widget)
	new_parent_widget.children_root.add_child(item_widget)
	item_widget.parent_widget = new_parent_widget
	if new_index + 1 != new_parent.get_child_count():
		new_parent_widget.children_root.move_child(item_widget, new_config_index)
	var config := item_widget.config.get_raw()
	erase_child_config(old_parent_widget, config)
	var children: Array = new_parent_widget.config.get_raw().get_or_add("Children", [])
	children.insert(mini(new_config_index, len(children)), config)

func reposition_row(item: TreeItem) -> void:
	var parent := item.get_parent()
	if _is_slotted(item):
		_move_tree_item(item, parent, parent.get_child_count() - 1)
		return
	for i in parent.get_child_count():
		var sibling := parent.get_child(i)
		if sibling != item and _is_slotted(sibling):
			_move_tree_item(item, parent, i if i < item.get_index() else i - 1)
			return

static func erase_child_config(parent_widget: UiScreen.Widget, config: Dictionary) -> void:
	var children := parent_widget.config.get_array("Children")
	for i in len(children):
		if is_same(children[i], config):
			children.remove_at(i)
			return

static func rename_info(screen: UiScreen, from: String, to: String) -> void:
	if from in screen.widgets_info:
		var entry := screen.widgets_info[from]
		screen.widgets_info.erase(from)
		entry.set_value("name", to)
		screen.widgets_info[to] = entry

static func set_info_hidden(screen: UiScreen, name: String, hidden: bool) -> void:
	var entry: SafeDict = screen.widgets_info.get_or_add(name, SafeDict.new({"name": name}))
	entry.set_value("hidden", hidden)

func _on_item_activated() -> void:
	var item := get_selected()
	if _is_style_owned(item):
		return
	_name_before = item.get_text(0)
	item.set_editable(0, true)
	edit_selected()

func _on_item_edited() -> void:
	var item := get_selected()
	item.set_editable(0, false)
	var widget := _get_widget(item)
	var old_name := _name_before
	var name_after := item.get_text(0)
	if name_after == old_name:
		return
	name_after = ScreenEditor.unique_name(widget.screen, name_after)
	var screen := widget.screen
	undo_redo.create_action("Rename widget")
	undo_redo.add_do_method(func ():
		widget.full_name = name_after
		rename_info(screen, old_name, name_after)
		widget.emit_signal("update")
	)
	undo_redo.add_undo_method(func ():
		widget.full_name = old_name
		rename_info(screen, name_after, old_name)
		widget.emit_signal("update")
	)
	undo_redo.commit_action()

func _on_item_selected() -> void:
	select_widget.emit(_get_widget(get_selected()))

func _on_item_button_clicked(item: TreeItem, _column: int, _id: int, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return
	var widget := _get_widget(item)
	var screen := widget.screen
	var name := widget.full_name
	var now_visible := widget.visible
	undo_redo.create_action("Hide widget")
	undo_redo.add_do_method(func ():
		widget.visible = not now_visible
		widget.state = UiScreen.WIDGET_STATE.NORMAL
		set_info_hidden(screen, name, now_visible)
		widget.emit_signal("update")
	)
	undo_redo.add_undo_method(func ():
		widget.visible = now_visible
		widget.state = UiScreen.WIDGET_STATE.NORMAL
		set_info_hidden(screen, name, not now_visible)
		widget.emit_signal("update")
	)
	undo_redo.commit_action()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var item := get_item_at_position(event.position)
		if item == null:
			return
		set_selected(item, 0)
		select_widget.emit(_get_widget(item))
		_menu.set_item_disabled(_menu.get_item_index(MenuId.COPY), _is_style_owned(item))
		_menu.set_item_disabled(_menu.get_item_index(MenuId.PASTE), _is_style_owned(item))
		_menu.set_item_disabled(_menu.get_item_index(MenuId.DELETE), _is_style_owned(item) or _get_widget(item).parent_widget == null)
		_menu.position = Vector2i(get_screen_position() + event.position)
		_menu.popup()
		accept_event()

func _on_menu_id_pressed(id: int) -> void:
	var item := get_selected()
	if item == null:
		return
	match id:
		MenuId.COPY: copy_requested.emit(_get_widget(item))
		MenuId.PASTE: paste_requested.emit(_get_widget(item), item)
		MenuId.DELETE: delete_requested.emit(_get_widget(item), item)
