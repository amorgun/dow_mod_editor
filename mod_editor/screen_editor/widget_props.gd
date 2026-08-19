class_name WidgetProps extends TabContainer

signal prop_changed(key: String, value: Variant)
signal prop_removed(key: String)
signal style_selected(sheet: String, style_name: String)
signal slot_selected(slot: int)

var widget: UiScreen.Widget = null
var editable := true

@onready var rows_box: VBoxContainer = $Properties/Rows
@onready var art_tab: ItemListTab = $Art
@onready var hit_tab: ItemListTab = $HitArea

var _style_ids: Array = []
var _slot_values: Array = []

var _style_row: HBoxContainer = null
var _style_options: OptionButton = null
var _style_names: Array[String] = []

## Drops the cached style dropdown; call when another screen file is opened.
func reset_style_cache() -> void:
	if _style_row != null:
		_style_row.queue_free()
	_style_row = null
	_style_options = null

func set_widget(widget_: UiScreen.Widget, editable_: bool) -> void:
	widget = widget_
	editable = editable_
	art_tab.widget = widget_
	art_tab.editable = editable_
	hit_tab.widget = widget_
	hit_tab.editable = editable_
	sync_display()

func sync_display() -> void:
	for c in rows_box.get_children():
		rows_box.remove_child(c)
		if c != _style_row:
			c.queue_free()
	if widget != null:
		_add_style_row()
		if widget.parent_widget != null:
			_add_slot_row()
		var own := widget.config.get_raw()
		var style := widget._get_style_config_raw()
		for descriptor in ScreenPropDefs.widget_props(widget.get_effective_config().get_str("type")):
			var key: String = descriptor["key"]
			var row := PropRow.new(descriptor)
			if editable:
				row.setup(own.get(key), key in own, style.get(key), key in style)
			else:
				row.setup(null, false, own.get(key, style.get(key)), key in own or key in style, false)
			row.changed.connect(func (k: String, value: Variant): prop_changed.emit(k, value))
			row.add_requested.connect(func (k: String): prop_changed.emit(k, ScreenPropDefs.default_value(descriptor)))
			row.override_requested.connect(func (k: String):
				var val = style.get(k)
				prop_changed.emit(k, val.duplicate(true) if val is Dictionary or val is Array else val)
			)
			row.reset_requested.connect(func (k: String): prop_removed.emit(k))
			rows_box.add_child(row)
	art_tab.sync_display(true)
	hit_tab.sync_display(true)

func _add_labeled_option(label_text: String) -> OptionButton:
	var box := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	box.add_child(label)
	var options := OptionButton.new()
	options.clip_text = true
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(options)
	rows_box.add_child(box)
	return options

func _add_style_row() -> void:
	# the style list is large and rebuilding the popup per selection is slow:
	# build the dropdown once per screen and reuse it
	if _style_row == null:
		_build_style_row()
	rows_box.add_child(_style_row)
	_style_options.disabled = not editable
	var index := 0
	var widget_style := widget.config.get_array("style")
	if len(widget_style) == 2:
		var current := "%s - %s" % [str(widget_style[0]).to_lower(), widget_style[1]]
		index = maxi(0, _style_names.find(current) + 1)
	_style_options.select(index)

func _build_style_row() -> void:
	_style_row = HBoxContainer.new()
	var label := Label.new()
	label.text = "style"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	_style_row.add_child(label)
	_style_options = OptionButton.new()
	_style_options.clip_text = true
	_style_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_row.add_child(_style_options)
	_style_ids = [[]]
	_style_options.add_item("None")
	_style_names = []
	var styles := widget.screen.common_styles
	for sheet in styles:
		for style_name in styles[sheet]:
			_style_names.append("%s - %s" % [sheet, style_name])
	_style_names.sort()
	for option_name in _style_names:
		_style_options.add_item(option_name)
		_style_ids.append(option_name.split(" - "))
	var popup: PopupMenu = _style_options.get_popup()
	for i in popup.get_item_count():
		popup.set_item_as_radio_checkable(i, false)
	_style_options.item_selected.connect(func (idx: int):
		var id: Array = _style_ids[idx]
		style_selected.emit(id[0] if len(id) == 2 else "", id[1] if len(id) == 2 else "")
	)

func _current_slot() -> int:
	var parent := widget.parent_widget
	for s in UiScreen.Slot.values():
		if parent.get_widget_slot(s, UiScreen.SlotType.OWN) == widget:
			return s
	return -1

func _add_slot_row() -> void:
	var options := _add_labeled_option("slot")
	options.disabled = not editable
	var parent := widget.parent_widget
	var current := _current_slot()
	_slot_values = [-1]
	options.add_item("None")
	for s in ScreenPropDefs.parent_slots(parent.get_effective_config().get_str("type")):
		if s != current and parent.get_widget_slot(s, UiScreen.SlotType.OWN) != null:
			continue
		options.add_item(UiScreen.Slot.keys()[s])
		_slot_values.append(s)
	options.select(_slot_values.find(current))
	options.item_selected.connect(func (idx: int): slot_selected.emit(_slot_values[idx]))
