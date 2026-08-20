class_name ItemListTab extends VBoxContainer

enum ItemKind {
	ART,
	HIT,
	GUIDES,
}

@export var kind: ItemKind = ItemKind.ART

## GUIDES items live on the screen, not on the selected widget.
var screen: UiScreen = null

signal item_selected(index: int)
signal item_prop_changed(index: int, key: String, value: Variant)
signal item_prop_removed(index: int, key: String)
signal item_added(type: String)
signal item_moved(from_index: int, to_index: int)
signal fill_requested(index: int)
signal override_requested()

var widget: UiScreen.Widget = null
var editable := true

var _list: ItemBlobList
var _rows_box: VBoxContainer
var _override_button: Button
var _fill_button: Button

func _ready() -> void:
	var toolbar := HBoxContainer.new()
	add_child(toolbar)
	var add_menu := MenuButton.new()
	add_menu.text = "Add"
	var add_popup := add_menu.get_popup()
	var add_types: Array[String] = ScreenPropDefs.ART_TYPES
	match kind:
		ItemKind.HIT: add_types = ScreenPropDefs.HIT_TYPES
		ItemKind.GUIDES: add_types = ScreenPropDefs.GUIDE_TYPES
	for t in add_types:
		add_popup.add_item(t)
	add_popup.index_pressed.connect(func (idx: int): item_added.emit(add_popup.get_item_text(idx)))
	toolbar.add_child(add_menu)
	if kind == ItemKind.HIT:
		_fill_button = _add_tool_button(toolbar, "Fill Widget", func (): _emit_for_selection(fill_requested))
	_override_button = _add_tool_button(toolbar, "Override", func (): override_requested.emit())

	_list = ItemBlobList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func (): item_selected.emit(selected_index()))
	_list.reordered.connect(func (from_index: int, to_index: int): item_moved.emit(from_index, to_index))
	add_child(_list)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows_box)
	add_child(scroll)

func _add_tool_button(toolbar: HBoxContainer, text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(handler)
	toolbar.add_child(button)
	return button

func _emit_for_selection(sig: Signal) -> void:
	var index := selected_index()
	if index >= 0:
		sig.emit(index)

func selected_index() -> int:
	return _list.selected

func display_items(target: UiScreen.Widget = widget) -> Array:
	if kind == ItemKind.GUIDES:
		return screen.guides if screen != null else []
	if target == null:
		return []
	return _raw_items(target.config.get_raw() if is_own(target) else target._get_style_config_raw())

func _raw_items(config: Dictionary) -> Array:
	if kind == ItemKind.ART:
		var presentation = config.get("Presentation", {})
		if presentation is not Dictionary:
			return []
		var art = presentation.get("Art", [])
		return art if art is Array else []
	var hits = config.get("HitArea", [])
	return hits if hits is Array else []

func is_own(target: UiScreen.Widget = widget) -> bool:
	if kind == ItemKind.GUIDES:
		return true
	if target == null:
		return false
	var raw := target.config.get_raw()
	if kind == ItemKind.ART:
		return raw.get("Presentation", null) is Dictionary
	return raw.get("HitArea", null) is Array

func sync_display(keep_selection: bool = false) -> void:
	var selected := selected_index() if keep_selection else -1
	_list.clear()
	var items := display_items()
	var own := editable and is_own()
	for i in len(items):
		var item_config := SafeDict.new(items[i] if items[i] is Dictionary else {})
		var label: String
		if kind == ItemKind.GUIDES:
			var item: Dictionary = items[i] if items[i] is Dictionary else {}
			label = "%s  %.3f" % ["horizontal" if item.get("horizontal", false) else "vertical", float(item.get("position", 0.0))]
		else:
			label = item_config.get_str("type", "?")
			match item_config.get_str("type"):
				"Graphic": label += "  %s" % item_config.get_str("texture").get_file()
				"Text": label += "  %s" % item_config.get_str("fontname")
		_list.add_item(label, item_config.get_array("states") if kind == ItemKind.ART else null)
	_override_button.visible = editable and widget != null and not is_own()
	_list.reorder_enabled = own
	if _fill_button != null:
		_fill_button.disabled = not own
	if keep_selection and selected >= 0 and selected < len(items):
		_list.select(selected)
	else:
		_sync_rows(-1)

func _sync_rows(index: int) -> void:
	for c in _rows_box.get_children():
		_rows_box.remove_child(c)
		c.queue_free()
	var items := display_items()
	if index < 0 or index >= len(items):
		return
	var item_config: Dictionary = items[index] if items[index] is Dictionary else {}
	var own := editable and is_own()
	var type := str(item_config.get("type", ""))
	var descriptors := ScreenPropDefs.art_props(type)
	match kind:
		ItemKind.HIT: descriptors = ScreenPropDefs.hit_props(type)
		ItemKind.GUIDES: descriptors = ScreenPropDefs.guide_props(type)
	for descriptor in descriptors:
		var row := PropRow.new(descriptor)
		var key: String = descriptor["key"]
		if own:
			row.setup(item_config.get(key), key in item_config, null, false)
		else:
			row.setup(null, false, item_config.get(key), key in item_config, false)
		row.changed.connect(func (k: String, value: Variant): item_prop_changed.emit(selected_index(), k, value))
		row.reset_requested.connect(func (k: String): item_prop_removed.emit(selected_index(), k))
		row.add_requested.connect(func (k: String): item_prop_changed.emit(selected_index(), k, ScreenPropDefs.default_value(descriptor)))
		_rows_box.add_child(row)

func sync_selection() -> void:
	_sync_rows(selected_index())

func select_item(index: int) -> void:
	_list.select(index)
