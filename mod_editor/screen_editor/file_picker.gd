## Modal file picker over the mod filesystem. The folder view, the preview,
## and the stored value are configured through callbacks.
class_name ModFilePicker extends ConfirmationDialog

signal picked(value: String)

var loader: ModResourceLoader
## Navigation floor: ".." never rises above it.
var root := "data:"
## (dir_path: String, files: PackedStringArray) -> Array of display entries.
var list_entries := Callable()
## (dir_path: String, entry: String) -> Image; invalid Callable = no preview pane.
var load_preview := Callable()
## (dir_path: String, entry: String) -> String stored in the config.
var make_value := Callable()

var _dir := ""
var _path_label: Label
var _list: ItemList
var _preview: TextureRect
var _icon_folder := ImageTexture.create_from_image(Settings.data.pload_svg("data:art/ui/textures/Folder.svg", Color("e0e0e0")))
var _icon_file := ImageTexture.create_from_image(Settings.data.pload_svg("data:art/ui/textures/File.svg", Color("e0e0e0")))

func _init() -> void:
	title = "Select File"
	min_size = Vector2i(720, 460)
	var box := HSplitContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_label = Label.new()
	_path_label.clip_text = true
	left.add_child(_path_label)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_activated.connect(_on_item_activated)
	_list.item_selected.connect(_on_item_selected)
	left.add_child(_list)
	box.add_child(left)
	_preview = TextureRect.new()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.custom_minimum_size = Vector2(280, 0)
	box.add_child(_preview)
	add_child(box)
	confirmed.connect(_on_confirmed)

func open(start_dir: String) -> void:
	_preview.visible = load_preview.is_valid()
	_show_dir(start_dir if start_dir.begins_with(root) else root)
	popup_centered()

func _parent_dir() -> String:
	var base := _dir.get_base_dir()
	return base if base.contains(":") else root

func _show_dir(path: String) -> void:
	_dir = path
	_path_label.text = path
	_list.clear()
	_preview.texture = null
	if _dir != root:
		_list.add_item("..", _icon_folder)
		_list.set_item_metadata(_list.item_count - 1, true)
	var dirs := Array(loader.plist_dirs(_dir))
	dirs.sort()
	for d in dirs:
		_list.add_item(d, _icon_folder)
		_list.set_item_metadata(_list.item_count - 1, true)
	var files := loader.plist_files(_dir)
	var entries: Array = list_entries.call(_dir, files) if list_entries.is_valid() else Array(files)
	entries.sort()
	for e in entries:
		_list.add_item(e, _icon_file)

func _on_item_activated(index: int) -> void:
	var text := _list.get_item_text(index)
	if text == "..":
		_show_dir(_parent_dir())
	elif _list.get_item_metadata(index):
		_show_dir(_dir.path_join(text))
	else:
		picked.emit(make_value.call(_dir, text))
		hide()

func _on_item_selected(index: int) -> void:
	if not load_preview.is_valid() or _list.get_item_metadata(index):
		return
	var img: Image = load_preview.call(_dir, _list.get_item_text(index))
	_preview.texture = ImageTexture.create_from_image(img) if img != null else null

func _on_confirmed() -> void:
	var sel := _list.get_selected_items()
	if len(sel) == 0 or _list.get_item_metadata(sel[0]):
		return
	picked.emit(make_value.call(_dir, _list.get_item_text(sel[0])))
