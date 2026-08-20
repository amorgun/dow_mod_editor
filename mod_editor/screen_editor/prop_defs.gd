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
const WIDGET_EXTRA: Dictionary[String, Array] = {
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
	"Swf": [{"key": "swf", "kind": Kind.STRING}],
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
		{"key": "horizontal", "kind": Kind.BOOL},
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

const ART_EXTRA: Dictionary[String, Array] = {
	"Graphic": [
		{"key": "texture", "kind": Kind.STRING},
		{"key": "flipVertical", "kind": Kind.BOOL},
		{"key": "flipHorizontal", "kind": Kind.BOOL},
		{"key": "isTextureStatic", "kind": Kind.BOOL},
		{"key": "dropShadowSize", "kind": Kind.NUMBER},
	],
	"Text": [
		{"key": "fontname", "kind": Kind.STRING},
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
