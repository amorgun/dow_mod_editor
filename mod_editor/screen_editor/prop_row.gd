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
			var picker := ColorPickerButton.new()
			picker.disabled = not editable
			picker.popup_closed.connect(func ():
				var c := picker.color
				_emit_changed([
					int(round(c.r * 255)), int(round(c.g * 255)),
					int(round(c.b * 255)), int(round(c.a * 255)),
				])
			)
			res = picker
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
			if value is Array and len(value) == 4:
				_editor.color = Color.from_rgba8(value[0], value[1], value[2], value[3])
			elif value is String:
				_editor.tooltip_text = value  # named colour from the .colours table
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
