## One property editor row: missing -> [Add]; style-defined -> read-only + [Override]; own -> editable + [Reset].
class_name PropRow extends HBoxContainer

signal changed(key: String, value: Variant)
signal add_requested(key: String)
signal override_requested(key: String)
signal reset_requested(key: String)

const STATE_NAMES: Array[String] = ["Normal", "Hover", "Active", "Disabled"]

var descriptor: Dictionary
var key: String
var _editor: Control = null
var _last_value: Variant = null
var _color_popup: PopupPanel = null
var _color_picker: ColorPicker = null

static var _palette_colors: Dictionary = {}
static var _palette_names: Array = []
static var _palette_icons: Dictionary = {}

## Named colours from the screen's .colours tables; icons cached per file open.
static func set_palette(colors: Dictionary) -> void:
	_palette_colors = colors
	_palette_names = colors.keys()
	_palette_names.sort()
	_palette_icons.clear()
	for color_name in _palette_names:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(colors[color_name])
		_palette_icons[color_name] = ImageTexture.create_from_image(img)

func _init(descriptor_: Dictionary) -> void:
	descriptor = descriptor_
	key = descriptor["key"]
	var label := Label.new()
	label.text = key
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	add_child(label)

func setup(own_value: Variant, has_own: bool, style_value: Variant, has_style: bool, allow_actions: bool = true) -> void:
	for c in get_children().slice(1):
		remove_child(c)
		c.queue_free()
	_editor = null
	if has_own:
		_editor = _make_editor(true)
		_set_editor_value(own_value)
		_last_value = own_value
		if allow_actions:
			_add_action_button("Reset", func (): call_deferred("emit_signal", "reset_requested", key))
	elif has_style:
		_editor = _make_editor(false)
		_set_editor_value(style_value)
		_last_value = style_value
		if allow_actions:
			_add_action_button("Override", func (): call_deferred("emit_signal", "override_requested", key))
	else:
		if allow_actions:
			_add_action_button("Add", func (): call_deferred("emit_signal", "add_requested", key))
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(spacer)

func _add_action_button(text: String, handler: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(handler)
	add_child(button)

## Deferred so the emitting editor control finishes its own signal stack before
## the handlers rebuild (and free) the rows — freeing mid-emission crashes.
func _emit_changed(value: Variant) -> void:
	if value == _last_value:
		return
	_last_value = value
	call_deferred("emit_signal", "changed", key, value)

func _popup_color_picker(anchor: Control) -> void:
	if _color_popup == null:
		_color_popup = PopupPanel.new()
		_color_picker = ColorPicker.new()
		_color_popup.add_child(_color_picker)
		add_child(_color_popup)
		_color_popup.popup_hide.connect(func ():
			var c := _color_picker.color
			_emit_changed([
				int(round(c.r * 255)), int(round(c.g * 255)),
				int(round(c.b * 255)), int(round(c.a * 255)),
			])
		)
	if _last_value is Array and len(_last_value) == 4:
		_color_picker.color = Color.from_rgba8(_last_value[0], _last_value[1], _last_value[2], _last_value[3])
	elif _last_value is String:
		_color_picker.color = _palette_colors.get(_last_value, Color.WHITE)
	_color_popup.popup(Rect2i(Vector2i(anchor.get_screen_position()) + Vector2i(0, int(anchor.size.y)), Vector2i.ZERO))

static func _states_text(states: Array) -> String:
	var letters := PackedStringArray()
	for s in STATE_NAMES:
		if s in states:
			letters.append(s[0])
	return "|".join(letters) if len(letters) else "-"

static func _fmt(v: Variant) -> String:
	return str(snappedf(v, 0.001)) if v is float else str(v)

static func _parse_number(text: String) -> Variant:
	if text.is_valid_int():
		return text.to_int()
	if text.is_valid_float():
		return text.to_float()
	return null

func _make_editor(editable: bool) -> Control:
	var res: Control
	match descriptor["kind"]:
		ScreenPropDefs.Kind.STRING:
			var edit := LineEdit.new()
			edit.editable = editable
			var commit := func ():
				_emit_changed(edit.text)
			edit.text_submitted.connect(func (_t: String): commit.call())
			edit.focus_exited.connect(commit)
			res = edit
		ScreenPropDefs.Kind.NUMBER:
			var edit := LineEdit.new()
			edit.editable = editable
			var commit := func ():
				var val: Variant = _parse_number(edit.text)
				if val != null:
					_emit_changed(val)
			edit.text_submitted.connect(func (_t: String): commit.call())
			edit.focus_exited.connect(commit)
			res = edit
		ScreenPropDefs.Kind.BOOL:
			var check := CheckBox.new()
			check.disabled = not editable
			check.toggled.connect(func (val: bool): _emit_changed(val))
			res = check
		ScreenPropDefs.Kind.COLOR:
			var options := OptionButton.new()
			options.disabled = not editable
			options.clip_text = true
			options.add_item("Custom")
			for color_name in _palette_names:
				options.add_icon_item(_palette_icons[color_name], color_name)
			var popup := options.get_popup()
			for i in popup.get_item_count():
				popup.set_item_as_radio_checkable(i, false)
			options.item_selected.connect(func (idx: int):
				if idx == 0:
					_popup_color_picker(options)
				else:
					_emit_changed(_palette_names[idx - 1])
			)
			res = options
		ScreenPropDefs.Kind.VEC2:
			var box := HBoxContainer.new()
			for i in 2:
				var edit := LineEdit.new()
				edit.editable = editable
				edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				box.add_child(edit)
			var commit := func ():
				var x: Variant = _parse_number(box.get_child(0).text)
				var y: Variant = _parse_number(box.get_child(1).text)
				if x != null and y != null:
					_emit_changed([x, y])
			for c in box.get_children():
				c.text_submitted.connect(func (_t: String): commit.call())
				c.focus_exited.connect(commit)
			res = box
		ScreenPropDefs.Kind.ENUM:
			var options := OptionButton.new()
			options.disabled = not editable
			for o in descriptor["options"]:
				options.add_item(o)
			options.item_selected.connect(func (idx: int): _emit_changed(descriptor["options"][idx]))
			res = options
		ScreenPropDefs.Kind.STATES:
			var menu := MenuButton.new()
			menu.disabled = not editable
			menu.text = "-"
			var popup := menu.get_popup()
			popup.hide_on_checkable_item_selection = false
			for s in STATE_NAMES:
				popup.add_check_item(s)
			popup.index_pressed.connect(func (idx: int):
				popup.set_item_checked(idx, not popup.is_item_checked(idx))
				var val := []
				for i in popup.get_item_count():
					if popup.is_item_checked(i):
						val.append(STATE_NAMES[i])
				menu.text = _states_text(val)
				_emit_changed(val)
			)
			res = menu
	res.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(res)
	return res

func _set_editor_value(value: Variant) -> void:
	match descriptor["kind"]:
		ScreenPropDefs.Kind.STRING:
			_editor.text = str(value)
		ScreenPropDefs.Kind.NUMBER:
			_editor.text = str(value)
		ScreenPropDefs.Kind.BOOL:
			_editor.set_pressed_no_signal(bool(value))
		ScreenPropDefs.Kind.COLOR:
			var idx: int = _palette_names.find(value) if value is String else -1
			_editor.select(idx + 1)
		ScreenPropDefs.Kind.VEC2:
			if value is Array and len(value) == 2:
				_editor.get_child(0).text = _fmt(value[0])
				_editor.get_child(1).text = _fmt(value[1])
		ScreenPropDefs.Kind.ENUM:
			var idx: int = descriptor["options"].find(str(value))
			if idx >= 0:
				_editor.select(idx)
		ScreenPropDefs.Kind.STATES:
			var popup: PopupMenu = _editor.get_popup()
			var states: Array = value if value is Array else []
			for i in popup.get_item_count():
				popup.set_item_checked(i, STATE_NAMES[i] in states)
			_editor.text = _states_text(states)
