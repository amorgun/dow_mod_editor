class_name ScreenPropDefs

enum Kind {
	STRING,
	NUMBER,
	BOOL,
	COLOR,
	VEC2,
	ENUM,
	STATES,
}

const WIDGET_TYPES: Array[String] = [
	"ArtLabel", "Button", "CheckButton", "ComboBox", "Component", "Custom",
	"CustomListBox", "CustomListBoxItem", "EditText", "Group", "ProgressBar",
	"RadioButton", "ScrollBar", "Swf", "TextLabel", "TextListBox", "TextListBoxItem",
]

## Descriptor for a prop mirrored onto a real Control attribute: "apply" is
## called with (widget, effective value) after every config change of "key".
static func control_prop(key: String, kind: Kind, apply: Callable, default: Variant) -> Dictionary:
	return {"key": key, "kind": kind, "apply": apply, "default": default}

## A string prop holding a mod file path, picked with ModFilePicker.
## root is the navigation floor, start_dir the initial folder; the callbacks
## configure the folder view, the preview, and the stored value.
static func path_prop(key: String, root: String, start_dir: String, list_entries: Callable, load_preview: Callable, make_value: Callable) -> Dictionary:
	return {"key": key, "kind": Kind.STRING, "picker": {
		"root": root, "start_dir": start_dir, "list_entries": list_entries,
		"load_preview": load_preview, "make_value": make_value,
	}}

const IMAGE_EXTS: Array[String] = ["rtx", "dds", "tga"]

static func _image_entries(_dir: String, files: PackedStringArray) -> Array:
	var seen: Dictionary[String, bool] = {}
	var res: Array = []
	for f in files:
		if f.get_extension() in IMAGE_EXTS and f.get_basename() not in seen:
			seen[f.get_basename()] = true
			res.append(f.get_basename())
	return res

static func _image_preview(dir: String, entry: String) -> Image:
	# the screen renderer's format priority: rtx, then dds, then tga
	var image: Image = PropRow.loader.pload_image(dir.path_join(entry) + ".rtx")
	if image == null:
		image = PropRow.loader.pload_image(dir.path_join(entry) + ".dds")
	if image != null:
		image.decompress()
		image.flip_y()
	else:
		image = PropRow.loader.pload_image(dir.path_join(entry) + ".tga")
	return image

static func _image_value(dir: String, entry: String) -> String:
	return dir.trim_prefix("data:").path_join(entry) + ".tga"

static func _swf_entries(_dir: String, files: PackedStringArray) -> Array:
	var res: Array = []
	for f in files:
		if f.get_extension() == "swf":
			res.append(f)
	return res

static func _swf_value(dir: String, entry: String) -> String:
	return "GENERIC:" + dir.trim_prefix("data:").path_join(entry).replace("/", "\\").to_upper()

static func _font_entries(_dir: String, files: PackedStringArray) -> Array:
	var res: Array = []
	for f in files:
		if f.get_extension() == "fnt":
			res.append(f.get_basename())
	return res

## Fonts are referenced by bare name: common_fonts keys are .fnt basenames.
static func _font_value(_dir: String, entry: String) -> String:
	return entry

## Props shown for every widget type. "name" is edited via the tree; "style" and
## the slot assignment get dedicated rows in the panel.
static var WIDGET_COMMON: Array[Dictionary] = [
	{"key": "type", "kind": Kind.ENUM, "options": WIDGET_TYPES},
	{"key": "position", "kind": Kind.VEC2},
	{"key": "size", "kind": Kind.VEC2},
	control_prop("visible", Kind.BOOL, func (w: UiScreen.Widget, v: Variant): w.visible = v, true),
	control_prop("Clip", Kind.BOOL, func (w: UiScreen.Widget, v: Variant): w.clip_contents = v, false),
	control_prop("alpha", Kind.NUMBER, func (w: UiScreen.Widget, v: Variant): w.modulate.a = v, 1.0),
	{"key": "enabled", "kind": Kind.BOOL, "default": true},
	{"key": "tooltip_name", "kind": Kind.STRING},
	{"key": "tooltip_text", "kind": Kind.STRING},
]

## Extra props per widget type; the raw config keeps any keys not listed here.
## Data stores a "horizontal" bool; the row shows a direction dropdown.
const DIRECTION_PROP := {"key": "horizontal", "kind": Kind.ENUM, "label": "direction", "options": ["horizontal", "vertical"], "values": [true, false], "default": true}

static var WIDGET_EXTRA: Dictionary[String, Array] = {
	"TextLabel": [
		{"key": "text", "kind": Kind.STRING},
		{"key": "multiline", "kind": Kind.BOOL},
	],
	"Button": [
		{"key": "text", "kind": Kind.STRING},
		{"key": "buttonType", "kind": Kind.ENUM, "options": ["ClickOnPress", "ClickOnRelease"]},
		{"key": "wantAlternate", "kind": Kind.BOOL},
	],
	"CheckButton": [{"key": "text", "kind": Kind.STRING}],
	"RadioButton": [
		{"key": "text", "kind": Kind.STRING},
		{"key": "wantAlternate", "kind": Kind.BOOL},
	],
	"Swf": [path_prop("swf", "data:", "data:art/ui/swf", _swf_entries, Callable(), _swf_value)],
	"EditText": [
		{"key": "text", "kind": Kind.STRING},
		{"key": "multiline", "kind": Kind.BOOL},
		{"key": "maxTextLength", "kind": Kind.NUMBER},
		{"key": "caretColourTop", "kind": Kind.COLOR, "pair": "caretColourBottom"},
		{"key": "caretColourBottom", "kind": Kind.COLOR, "pair": "caretColourTop"},
	],
	"ProgressBar": [
		{"key": "range", "kind": Kind.NUMBER},
		{"key": "stepSize", "kind": Kind.NUMBER},
	],
	"ScrollBar": [
		DIRECTION_PROP,
		{"key": "range", "kind": Kind.NUMBER},
		{"key": "stepSize", "kind": Kind.NUMBER},
	],
	"TextListBox": [
		{"key": "maxItems", "kind": Kind.NUMBER},
		{"key": "autoPopulate", "kind": Kind.NUMBER},
	],
	"CustomListBox": [{"key": "maxItems", "kind": Kind.NUMBER}],
	"ComboBox": [{"key": "maxItems", "kind": Kind.NUMBER}],
}

## Which slots a parent widget type offers; unknown types offer all of them.
const PARENT_SLOTS: Dictionary[String, Array] = {
	"Button": [UiScreen.Slot.Label],
	"ComboBox": [UiScreen.Slot.Label, UiScreen.Slot.ArrowButton, UiScreen.Slot.ListBox],
	"TextListBox": [UiScreen.Slot.ItemsGroup, UiScreen.Slot.ItemTemplate, UiScreen.Slot.ScrollBar],
	"CustomListBox": [UiScreen.Slot.ItemsGroup, UiScreen.Slot.ItemTemplate, UiScreen.Slot.ScrollBar],
	"ScrollBar": [UiScreen.Slot.ButtonIncrement, UiScreen.Slot.ButtonDecrement, UiScreen.Slot.ButtonTrack],
}

const ART_TYPES: Array[String] = ["Graphic", "Text", "Rectangle", "Line", "Triangle"]

const ART_COMMON: Array[Dictionary] = [
	{"key": "type", "kind": Kind.ENUM, "options": ART_TYPES},
	{"key": "position", "kind": Kind.VEC2},
	{"key": "size", "kind": Kind.VEC2},
	{"key": "states", "kind": Kind.STATES},
]

static var ART_EXTRA: Dictionary[String, Array] = {
	"Graphic": [
		path_prop("texture", "data:", "data:art/ui", _image_entries, _image_preview, _image_value),
		{"key": "flipVertical", "kind": Kind.BOOL},
		{"key": "flipHorizontal", "kind": Kind.BOOL},
		{"key": "isTextureStatic", "kind": Kind.BOOL},
		{"key": "dropShadowSize", "kind": Kind.NUMBER},
	],
	"Text": [
		path_prop("fontname", "data:font", "data:font", _font_entries, Callable(), _font_value),
		{"key": "horzAlign", "kind": Kind.ENUM, "options": ["Left", "Centre", "Right"]},
		{"key": "vertAlign", "kind": Kind.ENUM, "options": ["Top", "Centre", "Bottom"]},
		{"key": "dropShadow", "kind": Kind.BOOL},
		{"key": "padding", "kind": Kind.VEC2},
		{"key": "textColourTop", "kind": Kind.COLOR, "pair": "textColourBottom"},
		{"key": "textColourBottom", "kind": Kind.COLOR, "pair": "textColourTop"},
	],
	"Rectangle": [
		{"key": "colour", "kind": Kind.COLOR},
		{"key": "rectangleType", "kind": Kind.STRING},
	],
	"Line": [
		{"key": "p1", "kind": Kind.VEC2},
		{"key": "p2", "kind": Kind.VEC2},
		{"key": "colour", "kind": Kind.COLOR},
	],
	"Triangle": [
		{"key": "p1", "kind": Kind.VEC2},
		{"key": "p2", "kind": Kind.VEC2},
		{"key": "p3", "kind": Kind.VEC2},
		{"key": "colour", "kind": Kind.COLOR},
	],
}

const HIT_TYPES: Array[String] = ["Rectangle", "Triangle"]

const HIT_COMMON: Array[Dictionary] = [
	{"key": "position", "kind": Kind.VEC2},
	{"key": "size", "kind": Kind.VEC2},
]

const HIT_EXTRA: Dictionary[String, Array] = {
	"Triangle": [
		{"key": "p1", "kind": Kind.VEC2},
		{"key": "p2", "kind": Kind.VEC2},
		{"key": "p3", "kind": Kind.VEC2},
	],
}

static func widget_props(type: String) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	res.append_array(WIDGET_COMMON)
	res.append_array(WIDGET_EXTRA.get(type, []))
	return res

static func art_props(type: String) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	res.append_array(ART_COMMON)
	res.append_array(ART_EXTRA.get(type, []))
	return res

static func hit_props(type: String) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	res.append_array(HIT_COMMON)
	res.append_array(HIT_EXTRA.get(type, []))
	return res

## The key that must exist together with `key` ("" if none).
static func pair_of(descriptors: Array[Dictionary], key: String) -> String:
	for descriptor in descriptors:
		if descriptor["key"] == key:
			return descriptor.get("pair", "")
	return ""

static func parent_slots(parent_type: String) -> Array:
	return PARENT_SLOTS.get(parent_type, UiScreen.Slot.values())

static func item_template(type: String) -> Dictionary:
	match type:
		"Graphic": return {"type": "Graphic", "position": [0.0, 0.0], "size": [1.0, 1.0], "texture": "", "states": ["Normal", "Hover", "Active", "Disabled"]}
		"Text": return {"type": "Text", "position": [0.0, 0.0], "size": [1.0, 1.0], "states": ["Normal", "Hover", "Active", "Disabled"]}
		"Line": return {"type": "Line", "position": [0.0, 0.0], "size": [1.0, 1.0], "p1": [0.0, 0.0], "p2": [1.0, 1.0], "colour": [255, 255, 255, 255], "states": ["Normal", "Hover", "Active", "Disabled"]}
		"Triangle": return {"type": "Triangle", "position": [0.0, 0.0], "size": [1.0, 1.0], "p1": [0.0, 0.0], "p2": [1.0, 0.0], "p3": [0.5, 1.0], "colour": [255, 255, 255, 255], "states": ["Normal", "Hover", "Active", "Disabled"]}
		"Rectangle", _: return {"type": "Rectangle", "position": [0.0, 0.0], "size": [1.0, 1.0], "colour": [255, 255, 255, 255], "states": ["Normal", "Hover", "Active", "Disabled"]}

const GUIDE_TYPES: Array[String] = ["Guide"]

static var GUIDE_PROPS: Array[Dictionary] = [
	DIRECTION_PROP,
	{"key": "position", "kind": Kind.NUMBER},
]

static func guide_props(_type: String) -> Array[Dictionary]:
	return GUIDE_PROPS

static func guide_template(_type: String) -> Dictionary:
	return {"horizontal": true, "position": 0.5}

static func hit_template(type: String) -> Dictionary:
	match type:
		"Triangle": return {"type": "Triangle", "p1": [0.0, 0.0], "p2": [1.0, 0.0], "p3": [0.5, 1.0]}
		"Rectangle", _: return {"type": "Rectangle", "position": [0.0, 0.0], "size": [1.0, 1.0]}

static func default_value(descriptor: Dictionary) -> Variant:
	if "default" in descriptor:
		return descriptor["default"]
	match descriptor["kind"]:
		Kind.STRING: return ""
		Kind.NUMBER: return 0
		Kind.BOOL: return false
		Kind.COLOR: return [255, 255, 255, 255]
		Kind.VEC2: return [0.0, 0.0]
		Kind.ENUM: return descriptor["options"][0]
		Kind.STATES: return ["Normal"]
	return null
