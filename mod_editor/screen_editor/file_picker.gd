## Modal file picker over the mod filesystem. Navigates the ModInfo index,
## sharing its lazily loaded folder data with the file browser; the folder
## view, the preview, and the stored value are configured through callbacks.
class_name ModFilePicker extends ConfirmationDialog

signal picked(value: String)

var mod_info: ModInfo
## Navigation floor: ".." never rises above it.
var root := "data:"
## (dir_path: String, files: PackedStringArray) -> Array of display entries.
var list_entries := Callable()
## (dir_path: String, entry: String) -> Image; invalid Callable = no preview pane.
var load_preview := Callable()
## (dir_path: String, entry: String) -> String stored in the config.
var make_value := Callable()

var _folder: ModInfo.IndexFolder = null
var _dirs: Array = []
var _files: Array = []
var _path_edit: LineEdit
var _search: LineEdit
var _list: ItemList
var _preview: TextureRect
var _icon_folder := ImageTexture.create_from_image(Settings.data.pload_svg("data:art/ui/textures/Folder.svg", Color("e0e0e0")))
var _icon_file := ImageTexture.create_from_image(Settings.data.pload_svg("data:art/ui/textures/File.svg", Color("e0e0e0")))

func _init() -> void:
	title = "Select File"
	min_size = Vector2i(720, 480)
	var box := HSplitContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_edit = LineEdit.new()
	_path_edit.text_submitted.connect(_on_path_submitted)
	left.add_child(_path_edit)
	_search = LineEdit.new()
	_search.placeholder_text = "Search"
	_search.clear_button_enabled = true
	_search.text_changed.connect(func (_t: String): _render())
	left.add_child(_search)
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

func open(preferred_dir: String, fallback_dir := "") -> void:
	_preview.visible = load_preview.is_valid()
	var found := Core.find_folder(mod_info, preferred_dir)
	if not found.ok and fallback_dir != "":
		found = Core.find_folder(mod_info, fallback_dir)
	if not found.ok:
		found = Core.find_folder(mod_info, root)
	_show_folder(found.data)
	popup_centered()
	_search.grab_focus()

func _dir_path() -> String:
	return _folder.full_path().full_path

func _show_folder(folder: ModInfo.IndexFolder) -> void:
	Core.load_folder_content(folder, true)
	_folder = folder
	_path_edit.text = _dir_path()
	_search.text = ""
	_dirs = []
	for f in folder.folders.values():
		_dirs.append(f.name)
	_dirs.sort()
	var names := PackedStringArray()
	for f in folder.files.values():
		names.append(f.name)
	_files = list_entries.call(_dir_path(), names) if list_entries.is_valid() else Array(names)
	_files.sort()
	_render()

func _render() -> void:
	_list.clear()
	_preview.texture = null
	var filter := _search.text.to_lower()
	if _dir_path() != root:
		_list.add_item("..", _icon_folder)
		_list.set_item_metadata(_list.item_count - 1, true)
	for d in _dirs:
		if filter == "" or filter in str(d).to_lower():
			_list.add_item(d, _icon_folder)
			_list.set_item_metadata(_list.item_count - 1, true)
	for e in _files:
		if filter == "" or filter in str(e).to_lower():
			_list.add_item(e, _icon_file)

func _on_path_submitted(text: String) -> void:
	var found := Core.find_folder(mod_info, text)
	if found.ok:
		_show_folder(found.data)
	else:
		_path_edit.text = _dir_path()

func _on_item_activated(index: int) -> void:
	var text := _list.get_item_text(index)
	if text == "..":
		_show_folder(_folder.parent)
	elif _list.get_item_metadata(index):
		_show_folder(_folder.folders[text.to_lower()])
	else:
		picked.emit(make_value.call(_dir_path(), text))
		hide()

func _on_item_selected(index: int) -> void:
	if not load_preview.is_valid() or _list.get_item_metadata(index):
		return
	var img: Image = load_preview.call(_dir_path(), _list.get_item_text(index))
	_preview.texture = ImageTexture.create_from_image(img) if img != null else null

func _on_confirmed() -> void:
	var sel := _list.get_selected_items()
	if len(sel) == 0 or _list.get_item_metadata(sel[0]):
		return
	picked.emit(make_value.call(_dir_path(), _list.get_item_text(sel[0])))
