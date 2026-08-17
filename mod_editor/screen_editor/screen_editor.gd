class_name ScreenEditor extends Panel

enum ViewMode {
	INTERACTIVE,
	PICKER,
}

@onready var ui_screen: UiScreen = $VBoxContainer/Columns/Preview/UiScreeen
@onready var element_tree: WidgetTree = $VBoxContainer/Columns/ElementTree
@onready var selection: ResizerControl = $VBoxContainer/Columns/Preview/WidgetSelection
@onready var item_selection: ResizerControl = $VBoxContainer/Columns/Preview/ItemSelection
@onready var widget_props: WidgetProps = $VBoxContainer/Columns/Sidebar
@onready var mode_option: OptionButton = $VBoxContainer/TopBar/Mode

var undo_redo := UndoRedo.new()
var selected_widget: UiScreen.Widget
var _selected_editable := true

static var _widget_clipboard: Dictionary = {}
static var _item_clipboard: Dictionary = {}

var _pick_stack: Array[UiScreen.Widget] = []
var _pick_index := 0

signal close

func _on_close_button_pressed() -> void:
	close.emit()

func _ready() -> void:
	element_tree.undo_redo = undo_redo
	for tab in [widget_props.art_tab, widget_props.hit_tab]:
		tab.item_selected.connect(_on_item_selected.bind(tab))
		tab.item_prop_changed.connect(_on_item_prop_changed.bind(tab))
		tab.item_prop_removed.connect(_on_item_prop_removed.bind(tab))
		tab.item_added.connect(_on_item_added.bind(tab))
		tab.item_deleted.connect(_on_item_deleted.bind(tab))
		tab.item_moved.connect(_on_item_moved.bind(tab))
		tab.item_copied.connect(_on_item_copied.bind(tab))
		tab.item_pasted.connect(_on_item_pasted.bind(tab))
		tab.fill_requested.connect(_on_item_fill.bind(tab))
		tab.override_requested.connect(_on_items_override.bind(tab))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		selection.cancel_interaction()
		item_selection.cancel_interaction()
	if event.is_action_pressed("ui_undo", false, true):
		undo_redo.undo()
	elif event.is_action_pressed("ui_redo", false, true):
		undo_redo.redo()
	elif element_tree.has_focus() and selected_widget != null and _selected_editable:
		if event.is_action_pressed("ui_copy", false, true):
			_on_copy_widget(selected_widget)
		elif event.is_action_pressed("ui_paste", false, true):
			_on_paste_widget(selected_widget, element_tree.get_selected())
		elif event is InputEventKey and event.pressed and event.keycode == KEY_DELETE:
			if selected_widget.parent_widget != null:
				_on_delete_widget(selected_widget, element_tree.get_selected())

func setup_content(content: String, loader: ModResourceLoader) -> void:
	for c in ui_screen.get_children():
		ui_screen.remove_child(c)
		c.queue_free()
	var parser := ScreenParser.new(loader)
	parser.load_common_data()
	parser.load(content)
	parser.setup_view(ui_screen)
	element_tree.clear()
	var root := element_tree.create_item()
	for c in ui_screen.get_children():
		if c is UiScreen.Widget:
			_create_tree_items(c, root)
	selection.visible = false
	item_selection.visible = false
	selected_widget = null
	widget_props.set_widget(null, true)
	undo_redo.clear_history()
	_pick_stack = []

func _create_tree_items(node: UiScreen.Widget, root: TreeItem, slot: int = -1, style_owned: bool = false, do_recursive: bool = true) -> void:
	var it := element_tree.create_widget_node(node, root, slot, style_owned)
	if not node.has_user_signal("update"):
		node.add_user_signal("update")
	node.connect("update", element_tree.sync_item.bind(it))
	node.connect("update", _on_update_widget.bind(node))
	if not do_recursive:
		return
	for c in node.children_root.get_children():
		assert(c is UiScreen.Widget)
		_create_tree_items(c, it)
	for s in UiScreen.Slot:
		var widget_own := node.get_widget_slot(UiScreen.Slot[s], UiScreen.SlotType.OWN)
		if widget_own != null:
			_create_tree_items(widget_own, it, UiScreen.Slot[s])
			continue
		var widget_style := node.get_widget_slot(UiScreen.Slot[s], UiScreen.SlotType.STYLE)
		if widget_style != null:
			_create_tree_items(widget_style, it, UiScreen.Slot[s], true, false)

static func _slot_key(slot: int) -> String:
	return UiScreen.Slot.keys()[slot]

static func slot_of(widget: UiScreen.Widget) -> int:
	var parent := widget.parent_widget
	if parent == null:
		return -1
	for s in UiScreen.Slot.values():
		if parent.get_widget_slot(s, UiScreen.SlotType.OWN) == widget:
			return s
	return -1

static func collect_names(screen: UiScreen, taken: Dictionary = {}) -> Dictionary:
	for c in screen.get_children():
		if c is UiScreen.Widget:
			_collect_widget_names(c, taken)
	return taken

static func _collect_widget_names(widget: UiScreen.Widget, taken: Dictionary) -> void:
	taken[widget.full_name] = true
	for slot_root in widget.slot_roots.values():
		for type_root in slot_root.get_children():
			for c in type_root.get_children():
				if c is UiScreen.Widget:
					_collect_widget_names(c, taken)
	for c in widget.children_root.get_children():
		if c is UiScreen.Widget:
			_collect_widget_names(c, taken)

static func unique_name_in(taken: Dictionary, name: String) -> String:
	if name not in taken:
		taken[name] = true
		return name
	var base := name
	var dot := name.rfind(".")
	if dot != -1 and name.substr(dot + 1).is_valid_int():
		base = name.substr(0, dot)
	var i := 0
	while true:
		var candidate := "%s.%03d" % [base, i]
		if candidate not in taken:
			taken[candidate] = true
			return candidate
		i += 1
	return name

static func unique_name(screen: UiScreen, name: String) -> String:
	var taken := collect_names(screen)
	taken.erase(name)
	return unique_name_in(taken, name)

static func _num(v: float) -> Variant:
	return int(roundf(v)) if absf(v - roundf(v)) < 0.01 else v

func _reinit_subtree(widget: UiScreen.Widget) -> void:
	widget.init_size()
	widget.sync_display()
	for slot_root in widget.slot_roots.values():
		for type_root in slot_root.get_children():
			for c in type_root.get_children():
				if c is UiScreen.Widget:
					_reinit_subtree(c)
	for c in widget.children_root.get_children():
		if c is UiScreen.Widget:
			_reinit_subtree(c)

func _on_select_widget(widget: UiScreen.Widget) -> void:
	var screen_rect := ui_screen.get_global_rect()
	var widget_rect := widget.get_global_rect()

	selection.offset_left = 0
	selection.offset_top = 0
	selection.offset_right = 0
	selection.offset_bottom = 0

	selection.anchor_left = (widget_rect.position.x - screen_rect.position.x) / screen_rect.size.x
	selection.anchor_top = (widget_rect.position.y  - screen_rect.position.y) / screen_rect.size.y
	selection.anchor_right = (widget_rect.end.x - screen_rect.position.x) / screen_rect.size.x
	selection.anchor_bottom = (widget_rect.end.y - screen_rect.position.y) / screen_rect.size.y
	selection.visible = widget_props.current_tab == 0
	item_selection.visible = false

	if selected_widget != null and selected_widget.is_connected("update", widget_props.sync_display):
		selected_widget.disconnect("update", widget_props.sync_display)
	selected_widget = widget
	var item := element_tree.find_item(widget)
	_selected_editable = item == null or not item.get_meta("style_owned", false)
	widget_props.set_widget(widget, _selected_editable)
	widget.connect("update", widget_props.sync_display)

func _on_widget_select_update(_data: Vector2) -> void:
	var parent: UiScreen.Widget = selected_widget.parent_widget
	var rect_selection := selection.get_global_rect()
	var rect_parent := parent.get_global_rect()

	selected_widget.relative_pos = (rect_selection.position - rect_parent.position) / rect_parent.size
	selected_widget.relative_size = rect_selection.size / rect_parent.size
	selected_widget.sync_display()

func _on_update_widget(widget: UiScreen.Widget) -> void:
	widget.sync_display()
	if widget == selected_widget:
		_on_select_widget(widget)
		_update_item_gizmo()

func _on_widget_selection_edit_ended() -> void:
	if selected_widget == null or not _selected_editable:
		return
	var widget := selected_widget
	var parent_scale: Vector2 = widget._get_parent_scale()
	var new_pos := widget.relative_pos * parent_scale
	var new_size := widget.relative_size * parent_scale
	var raw := widget.config.get_raw()
	var had_pos: bool = "position" in raw
	var had_size: bool = "size" in raw
	var old_pos = raw.get("position")
	var old_size = raw.get("size")
	undo_redo.create_action("Edit widget box")
	undo_redo.add_do_method(func ():
		widget.config.set_value("position", [_num(new_pos.x), _num(new_pos.y)])
		widget.config.set_value("size", [_num(new_size.x), _num(new_size.y)])
		_reinit_subtree(widget)
		widget.emit_signal("update")
	)
	undo_redo.add_undo_method(func ():
		if had_pos: widget.config.set_value("position", old_pos)
		else: widget.config.erase("position")
		if had_size: widget.config.set_value("size", old_size)
		else: widget.config.erase("size")
		_reinit_subtree(widget)
		widget.emit_signal("update")
	)
	undo_redo.commit_action()

func _set_own_value(widget: UiScreen.Widget, key: String, value: Variant, has_value: bool, action_name: String) -> void:
	var raw := widget.config.get_raw()
	var had: bool = key in raw
	var old = raw.get(key)
	undo_redo.create_action(action_name)
	undo_redo.add_do_method(func ():
		if has_value: widget.config.set_value(key, value)
		else: widget.config.erase(key)
		_after_widget_config_change(widget, key)
	)
	undo_redo.add_undo_method(func ():
		if had: widget.config.set_value(key, old)
		else: widget.config.erase(key)
		_after_widget_config_change(widget, key)
	)
	undo_redo.commit_action()

func _after_widget_config_change(widget: UiScreen.Widget, key: String) -> void:
	if key in ["position", "size", "style"]:
		_reinit_subtree(widget)
	widget.emit_signal("update")

func _on_prop_changed(key: String, value: Variant) -> void:
	_set_own_value(selected_widget, key, value, true, "Set %s" % key)

func _on_prop_removed(key: String) -> void:
	_set_own_value(selected_widget, key, null, false, "Reset %s" % key)

func _on_style_selected(sheet: String, style_name: String) -> void:
	if sheet == "":
		_set_own_value(selected_widget, "style", null, false, "Clear style")
	else:
		_set_own_value(selected_widget, "style", [sheet, style_name], true, "Set style")

func _on_slot_selected(new_slot: int) -> void:
	var widget := selected_widget
	var old_slot := slot_of(widget)
	if widget == null or new_slot == old_slot:
		return
	undo_redo.create_action("Assign slot")
	undo_redo.add_do_method(func (): _assign_slot(widget, old_slot, new_slot))
	undo_redo.add_undo_method(func (): _assign_slot(widget, new_slot, old_slot))
	undo_redo.commit_action()

func _assign_slot(widget: UiScreen.Widget, from_slot: int, to_slot: int) -> void:
	var parent := widget.parent_widget
	var parent_raw := parent.config.get_raw()
	var config := widget.config.get_raw()
	if from_slot == -1:
		WidgetTree.erase_child_config(parent, config)
		parent.children_root.remove_child(widget)
	else:
		parent_raw.erase(_slot_key(from_slot))
		parent.slot_roots[from_slot].get_child(UiScreen.SlotType.OWN).remove_child(widget)
		var style_widget := parent.get_widget_slot(from_slot, UiScreen.SlotType.STYLE)
		if style_widget != null:
			style_widget.visible = true
	if to_slot == -1:
		parent_raw.get_or_add("Children", []).append(config)
		parent.children_root.add_child(widget)
	else:
		parent_raw[_slot_key(to_slot)] = config
		parent.slot_roots[to_slot].get_child(UiScreen.SlotType.OWN).add_child(widget)
		var style_widget := parent.get_widget_slot(to_slot, UiScreen.SlotType.STYLE)
		if style_widget != null:
			style_widget.visible = false
	var item := element_tree.find_item(widget)
	item.set_meta("slot", to_slot)
	element_tree.sync_item(item)
	element_tree.reposition_row(item)
	widget.emit_signal("update")

func _on_copy_widget(widget: UiScreen.Widget) -> void:
	var config := widget.config.get_raw().duplicate(true)
	var infos: Array = []
	_collect_infos(widget.screen, config, infos)
	_widget_clipboard = {"config": config, "infos": infos}

func _collect_infos(screen: UiScreen, config: Dictionary, infos: Array) -> void:
	var name := str(config.get("name", ""))
	if name in screen.widgets_info:
		infos.append(screen.widgets_info[name].get_raw().duplicate(true))
	for c in config.get("Children", []):
		if c is Dictionary:
			_collect_infos(screen, c, infos)
	for s in UiScreen.Slot.keys():
		if config.get(s) is Dictionary:
			_collect_infos(screen, config[s], infos)

func _uniquify_config(config: Dictionary, taken: Dictionary, renames: Dictionary) -> void:
	var name := str(config.get("name", ""))
	var new_name := unique_name_in(taken, name)
	if new_name != name:
		config["name"] = new_name
		renames[name] = new_name
	for c in config.get("Children", []):
		if c is Dictionary:
			_uniquify_config(c, taken, renames)
	for s in UiScreen.Slot.keys():
		if config.get(s) is Dictionary:
			_uniquify_config(config[s], taken, renames)

func _on_paste_widget(target: UiScreen.Widget, target_item: TreeItem) -> void:
	if _widget_clipboard.is_empty() or target == null or target_item == null:
		return
	var config: Dictionary = _widget_clipboard["config"].duplicate(true)
	var renames: Dictionary = {}
	_uniquify_config(config, collect_names(ui_screen), renames)
	var infos: Array = []
	for info in _widget_clipboard["infos"]:
		var entry: Dictionary = info.duplicate(true)
		entry["name"] = renames.get(str(entry.get("name", "")), entry.get("name"))
		infos.append(entry)
	undo_redo.create_action("Paste widget")
	undo_redo.add_do_method(func (): _insert_child_widget(target, target_item, config, infos, -1, -1))
	undo_redo.add_undo_method(func (): _remove_child_widget(target, config, infos))
	undo_redo.commit_action()

func _insert_child_widget(parent: UiScreen.Widget, parent_item: TreeItem, config: Dictionary, infos: Array, config_index: int, tree_index: int) -> void:
	for info in infos:
		ui_screen.widgets_info[str(info.get("name"))] = SafeDict.new(info)
	var children: Array = parent.config.get_raw().get_or_add("Children", [])
	if config_index < 0 or config_index > len(children):
		config_index = len(children)
	children.insert(config_index, config)
	var widget := ui_screen.build_widget_from_config(SafeDict.new(config), parent)
	parent.children_root.add_child(widget)
	parent.children_root.move_child(widget, config_index)
	var rows_before := parent_item.get_child_count()
	_create_tree_items(widget, parent_item)
	var row := parent_item.get_child(rows_before)
	if tree_index < 0:
		element_tree.reposition_row(row)
	elif tree_index < rows_before:
		row.move_before(parent_item.get_child(tree_index))
	_select_row(widget)

func _remove_child_widget(parent: UiScreen.Widget, config: Dictionary, infos: Array) -> void:
	for info in infos:
		ui_screen.widgets_info.erase(str(info.get("name")))
	WidgetTree.erase_child_config(parent, config)
	for c in parent.children_root.get_children():
		if c is UiScreen.Widget and is_same(c.config.get_raw(), config):
			_drop_widget_node(c)
			return

func _drop_widget_node(widget: UiScreen.Widget) -> void:
	if selected_widget != null and (selected_widget == widget or widget.is_ancestor_of(selected_widget)):
		selected_widget = null
		selection.visible = false
		item_selection.visible = false
		widget_props.set_widget(null, true)
	var item := element_tree.find_item(widget)
	if item != null:
		item.free()
	widget.get_parent().remove_child(widget)
	widget.queue_free()

func _on_delete_widget(widget: UiScreen.Widget, item: TreeItem) -> void:
	var parent := widget.parent_widget
	if parent == null:
		return
	var slot := slot_of(widget)
	var config := widget.config.get_raw()
	var infos: Array = []
	_collect_infos(ui_screen, config, infos)
	var parent_item := item.get_parent()
	var tree_index := item.get_index()
	var config_index := -1
	if slot == -1:
		config_index = element_tree.config_index(parent_item, tree_index)
	undo_redo.create_action("Delete widget")
	undo_redo.add_do_method(func (): _delete_widget(parent, config, infos, slot))
	undo_redo.add_undo_method(func (): _restore_widget(parent, parent_item, config, infos, slot, config_index, tree_index))
	undo_redo.commit_action()

func _delete_widget(parent: UiScreen.Widget, config: Dictionary, infos: Array, slot: int) -> void:
	if slot == -1:
		_remove_child_widget(parent, config, infos)
		return
	for info in infos:
		ui_screen.widgets_info.erase(str(info.get("name")))
	parent.config.get_raw().erase(_slot_key(slot))
	var widget := parent.get_widget_slot(slot, UiScreen.SlotType.OWN)
	if widget != null:
		_drop_widget_node(widget)
	var style_widget := parent.get_widget_slot(slot, UiScreen.SlotType.STYLE)
	if style_widget != null:
		style_widget.visible = true

func _restore_widget(parent: UiScreen.Widget, parent_item: TreeItem, config: Dictionary, infos: Array, slot: int, config_index: int, tree_index: int) -> void:
	if slot == -1:
		_insert_child_widget(parent, parent_item, config, infos, config_index, tree_index)
		return
	for info in infos:
		ui_screen.widgets_info[str(info.get("name"))] = SafeDict.new(info)
	parent.config.get_raw()[_slot_key(slot)] = config
	var widget := ui_screen.build_widget_from_config(SafeDict.new(config), parent)
	parent.slot_roots[slot].get_child(UiScreen.SlotType.OWN).add_child(widget)
	var style_widget := parent.get_widget_slot(slot, UiScreen.SlotType.STYLE)
	if style_widget != null:
		style_widget.visible = false
	var rows_before := parent_item.get_child_count()
	_create_tree_items(widget, parent_item, slot)
	if tree_index < rows_before:
		parent_item.get_child(rows_before).move_before(parent_item.get_child(tree_index))
	_select_row(widget)

func _select_row(widget: UiScreen.Widget) -> void:
	var item := element_tree.find_item(widget)
	if item != null:
		element_tree.set_selected(item, 0)
		element_tree.scroll_to_item(item)
	_on_select_widget(widget)

func _on_mode_selected(index: int) -> void:
	ui_screen.is_interactive = index == ViewMode.INTERACTIVE
	_pick_stack = []

func _on_canvas_gui_input(event: InputEvent) -> void:
	if mode_option.selected != ViewMode.PICKER:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hits := ui_screen.widgets_at(ui_screen.get_global_mouse_position())
		if hits == _pick_stack and len(hits) > 0:
			_pick_index = (_pick_index + 1) % len(hits)
		else:
			_pick_stack = hits
			_pick_index = 0
		if len(hits) > 0:
			_select_row(hits[_pick_index])

func _on_sidebar_tab_changed(_tab: int) -> void:
	selection.visible = selected_widget != null and widget_props.current_tab == 0
	_update_item_gizmo()

func _current_item_tab() -> ItemListTab:
	match widget_props.current_tab:
		1: return widget_props.art_tab
		2: return widget_props.hit_tab
	return null

func _update_item_gizmo() -> void:
	var tab := _current_item_tab()
	if tab == null or selected_widget == null:
		item_selection.visible = false
		return
	var index := tab.selected_index()
	var items := tab.display_items()
	if index < 0 or index >= len(items):
		item_selection.visible = false
		return
	var item_config := SafeDict.new(items[index] if items[index] is Dictionary else {})
	var widget_rect := selected_widget.get_global_rect()
	var rect := Rect2(
		widget_rect.position + item_config.get_vec2("position", Vector2.ZERO) * widget_rect.size,
		item_config.get_vec2("size", Vector2.ONE) * widget_rect.size,
	)
	var screen_rect := ui_screen.get_global_rect()
	item_selection.offset_left = 0
	item_selection.offset_top = 0
	item_selection.offset_right = 0
	item_selection.offset_bottom = 0
	item_selection.anchor_left = (rect.position.x - screen_rect.position.x) / screen_rect.size.x
	item_selection.anchor_top = (rect.position.y - screen_rect.position.y) / screen_rect.size.y
	item_selection.anchor_right = (rect.end.x - screen_rect.position.x) / screen_rect.size.x
	item_selection.anchor_bottom = (rect.end.y - screen_rect.position.y) / screen_rect.size.y
	item_selection.visible = tab.is_own() and tab.editable

func _on_item_selection_edit_ended() -> void:
	var tab := _current_item_tab()
	if tab == null or selected_widget == null:
		return
	var index := tab.selected_index()
	var items := tab.display_items()
	if index < 0 or index >= len(items):
		return
	var item: Dictionary = items[index]
	var widget_rect := selected_widget.get_global_rect()
	var rect := item_selection.get_global_rect()
	var new_pos := (rect.position - widget_rect.position) / widget_rect.size
	var new_size := rect.size / widget_rect.size
	var had_pos: bool = "position" in item
	var had_size: bool = "size" in item
	var old_pos = item.get("position")
	var old_size = item.get("size")
	undo_redo.create_action("Edit item box")
	undo_redo.add_do_method(func ():
		item["position"] = [new_pos.x, new_pos.y]
		item["size"] = [new_size.x, new_size.y]
		_after_item_change(tab)
	)
	undo_redo.add_undo_method(func ():
		if had_pos: item["position"] = old_pos
		else: item.erase("position")
		if had_size: item["size"] = old_size
		else: item.erase("size")
		_after_item_change(tab)
	)
	undo_redo.commit_action()

func _own_items(widget: UiScreen.Widget, tab: ItemListTab) -> Array:
	var raw := widget.config.get_raw()
	if tab.kind == ItemListTab.ItemKind.ART:
		var presentation = raw.get_or_add("Presentation", {})
		if presentation is not Dictionary:
			presentation = {}
			raw["Presentation"] = presentation
		return presentation.get_or_add("Art", [])
	var hits = raw.get_or_add("HitArea", [])
	if hits is not Array:
		hits = []
		raw["HitArea"] = hits
	return hits

func _after_item_change(tab: ItemListTab, select_index: int = -1) -> void:
	var widget := tab.widget
	widget.emit_signal("update")
	tab.sync_display(true)
	if select_index >= 0:
		tab.select_item(select_index)
	tab.sync_selection()
	_update_item_gizmo()

func _on_item_selected(_index: int, tab: ItemListTab) -> void:
	tab.sync_selection()
	_update_item_gizmo()

func _on_item_prop_changed(index: int, key: String, value: Variant, tab: ItemListTab) -> void:
	var item: Dictionary = tab.display_items()[index]
	var had: bool = key in item
	var old = item.get(key)
	undo_redo.create_action("Set item %s" % key)
	undo_redo.add_do_method(func ():
		item[key] = value
		_after_item_change(tab)
	)
	undo_redo.add_undo_method(func ():
		if had: item[key] = old
		else: item.erase(key)
		_after_item_change(tab)
	)
	undo_redo.commit_action()

func _on_item_prop_removed(index: int, key: String, tab: ItemListTab) -> void:
	var item: Dictionary = tab.display_items()[index]
	if key not in item:
		return
	var old = item[key]
	undo_redo.create_action("Reset item %s" % key)
	undo_redo.add_do_method(func ():
		item.erase(key)
		_after_item_change(tab)
	)
	undo_redo.add_undo_method(func ():
		item[key] = old
		_after_item_change(tab)
	)
	undo_redo.commit_action()

func _on_item_added(type: String, tab: ItemListTab) -> void:
	var widget := tab.widget
	var config := ScreenPropDefs.item_template(type) if tab.kind == ItemListTab.ItemKind.ART else {"type": type, "position": [0.0, 0.0], "size": [1.0, 1.0]}
	undo_redo.create_action("Add item")
	undo_redo.add_do_method(func ():
		var items := _own_items(widget, tab)
		items.append(config)
		_after_item_change(tab, len(items) - 1)
	)
	undo_redo.add_undo_method(func ():
		_erase_item(widget, tab, config)
		_after_item_change(tab)
	)
	undo_redo.commit_action()

func _erase_item(widget: UiScreen.Widget, tab: ItemListTab, config: Dictionary) -> void:
	var items := _own_items(widget, tab)
	for i in len(items):
		if is_same(items[i], config):
			items.remove_at(i)
			return

func _on_item_deleted(index: int, tab: ItemListTab) -> void:
	var widget := tab.widget
	var item: Dictionary = tab.display_items()[index]
	undo_redo.create_action("Delete item")
	undo_redo.add_do_method(func ():
		_erase_item(widget, tab, item)
		_after_item_change(tab)
	)
	undo_redo.add_undo_method(func ():
		_own_items(widget, tab).insert(index, item)
		_after_item_change(tab, index)
	)
	undo_redo.commit_action()

func _on_item_moved(from_index: int, to_index: int, tab: ItemListTab) -> void:
	var widget := tab.widget
	undo_redo.create_action("Move item")
	undo_redo.add_do_method(func ():
		var items := _own_items(widget, tab)
		var item = items.pop_at(from_index)
		items.insert(to_index, item)
		_after_item_change(tab, to_index)
	)
	undo_redo.add_undo_method(func ():
		var items := _own_items(widget, tab)
		var item = items.pop_at(to_index)
		items.insert(from_index, item)
		_after_item_change(tab, from_index)
	)
	undo_redo.commit_action()

func _on_item_copied(index: int, tab: ItemListTab) -> void:
	_item_clipboard = {"kind": tab.kind, "config": tab.display_items()[index].duplicate(true)}

func _on_item_pasted(tab: ItemListTab) -> void:
	if _item_clipboard.is_empty() or _item_clipboard["kind"] != tab.kind:
		return
	var widget := tab.widget
	var config: Dictionary = _item_clipboard["config"].duplicate(true)
	undo_redo.create_action("Paste item")
	undo_redo.add_do_method(func ():
		var items := _own_items(widget, tab)
		items.append(config)
		_after_item_change(tab, len(items) - 1)
	)
	undo_redo.add_undo_method(func ():
		_erase_item(widget, tab, config)
		_after_item_change(tab)
	)
	undo_redo.commit_action()

func _on_item_fill(index: int, tab: ItemListTab) -> void:
	var item: Dictionary = tab.display_items()[index]
	var had_pos: bool = "position" in item
	var had_size: bool = "size" in item
	var old_pos = item.get("position")
	var old_size = item.get("size")
	undo_redo.create_action("Fill widget")
	undo_redo.add_do_method(func ():
		item["position"] = [0.0, 0.0]
		item["size"] = [1.0, 1.0]
		_after_item_change(tab, index)
	)
	undo_redo.add_undo_method(func ():
		if had_pos: item["position"] = old_pos
		else: item.erase("position")
		if had_size: item["size"] = old_size
		else: item.erase("size")
		_after_item_change(tab, index)
	)
	undo_redo.commit_action()

func _on_items_override(tab: ItemListTab) -> void:
	var widget := tab.widget
	var style := widget._get_style_config_raw()
	undo_redo.create_action("Override items")
	if tab.kind == ItemListTab.ItemKind.ART:
		var presentation = style.get("Presentation", {})
		var own: Dictionary = presentation.duplicate(true) if presentation is Dictionary else {}
		own.get_or_add("Art", [])
		undo_redo.add_do_method(func ():
			widget.config.set_value("Presentation", own)
			_after_item_change(tab)
		)
		undo_redo.add_undo_method(func ():
			widget.config.erase("Presentation")
			_after_item_change(tab)
		)
	else:
		var hits = style.get("HitArea", [])
		var own: Array = hits.duplicate(true) if hits is Array else []
		undo_redo.add_do_method(func ():
			widget.config.set_value("HitArea", own)
			_after_item_change(tab)
		)
		undo_redo.add_undo_method(func ():
			widget.config.erase("HitArea")
			_after_item_change(tab)
		)
	undo_redo.commit_action()
