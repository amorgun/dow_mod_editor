class_name FileTree extends Tree

@export var updated_files_per_frame: int = 50
var _current_file_node: TreeItem
signal item_viewed(path: ModSet.ModPath, mod: ModInfo, file: ModInfo.IndexFile, tree_item: TreeItem, reload: bool)
signal mod_closed(mod: ModInfo)


# TODO make static
var _icon_loading_frames: Array[Image] = [
	Settings.data.pload_image("data:art/ui/textures/Progress1.svg"),
	Settings.data.pload_image("data:art/ui/textures/Progress2.svg"),
	Settings.data.pload_image("data:art/ui/textures/Progress3.svg"),
	Settings.data.pload_image("data:art/ui/textures/Progress4.svg"),
	Settings.data.pload_image("data:art/ui/textures/Progress5.svg"),
	Settings.data.pload_image("data:art/ui/textures/Progress6.svg"),
	Settings.data.pload_image("data:art/ui/textures/Progress7.svg"),
	Settings.data.pload_image("data:art/ui/textures/Progress8.svg"),
]
var _icon_error := Settings.data.pload_image("data:art/ui/textures/StatusError.svg")

const color_packed = Color("696969ff")
const color_unpacked = Color("e0e0e0")

var _icon_file_packed := Settings.data.pload_svg("data:art/ui/textures/File.svg", color_packed)
var _icon_file_unpacked := Settings.data.pload_svg("data:art/ui/textures/File.svg", color_unpacked)

var _icon_folder_packed := Settings.data.pload_svg("data:art/ui/textures/Folder.svg", color_packed)
var _icon_folder_unpacked := Settings.data.pload_svg("data:art/ui/textures/Folder.svg", color_unpacked)

@onready var rmb_menu: PopupMenu = $RmbMenu
@onready var open_mod_prompt: Control = $OpenModPrompt
var _rmb_item: TreeItem
enum RmbActions {
	RELOAD_MOD,
	CLOSE_MOD,
	VIEW,
	VIEW_MODULE,
	RELOAD_FILE,
	RELOAD_FOLDER,
	UNPACK,
	SHOW_IN_FILES,
	COPY,
	COPY_PATH,
}
var _finished_task_ids: PackedInt64Array = []
var _ready_mods: Dictionary[int, ModInfo] = {}
var _finished_task_mutex: Mutex
var _active_tasks: Dictionary[ModInfo, int] = {}
var _mod_root_nodes: Dictionary[ModInfo, TreeItem] = {}
var _updating_items: Dictionary[TreeItem, bool] = {}
var _active_loading_tasks: Dictionary[int, bool] = {}
var _finished_loading_tasks: Dictionary[int, bool] = {}


func add_mod(path: String) -> ModSet:
	var node := create_item()
	node.set_text(0, path.get_file().get_basename())
	var mod := ModSet.new()
	var mod_info := ModInfo.from_mod(mod, Settings.shadow_folder)
	node.set_meta("mod", mod_info)
	node.set_meta("index_item", mod_info.index)
	open_mod_prompt.visible = false
	if _load_mod(mod_info, path, node):
		return mod
	return

func _load_mod(mod_info: ModInfo, path: String, node: TreeItem) -> bool:
	_clear_tree(node)
	var err := mod_info.mod.load(path, Settings.extra_lookup_folders)
	if err != OK:
		node.set_meta("error", true)
		_updating_items[node] = true
		return false
	else:
		node.set_text(0, mod_info.name)
		node.set_collapsed_recursive(true)
		#_request_load(node)
		
		_mod_root_nodes[mod_info] = node
		_request_mod_preload(node, mod_info)
		return true

func _clear_tree(node: TreeItem) -> void:
	var clean_fn := func (it: TreeItem, me: Callable) -> void:
		if it.has_meta("preview"):
			it.get_meta("preview").queue_free()
		for c in it.get_children():
			me.call(c, me)
			c.free.call_deferred()

	clean_fn.call(node, clean_fn)

func _request_load(node: TreeItem) -> void:
	_set_loading(node)
	_clear_tree(node)
	var node_data = _get_node_path_data(node)
	var path: ModSet.ModPath = node_data[0]
	var mod_name: String = node_data[1].name
	var task_id := WorkerThreadPool.add_task(_load_item.bind(node), false, "[%s] Loading item %s" % [mod_name, path])
	_active_loading_tasks[task_id] = true

func _request_mod_preload(node: TreeItem, mod_info: ModInfo) -> void:
	_set_loading(node)
	var task_id := WorkerThreadPool.add_task(_preload_mod.bind(node, mod_info), false, "[%s] Preloar data" % [mod_info.name])
	_active_loading_tasks[task_id] = true

func _set_loading(node: TreeItem) -> void:
	node.set_meta("loading", true)
	_updating_items[node] = true

func _update_loading_icons() -> void:
	for node in _updating_items.keys():
		if node.get_meta("loading", false):
			var next_frame: int = (node.get_meta("loading_frame", -1) + 1) % len(_icon_loading_frames)
			node.set_icon(0, ImageTexture.create_from_image(_icon_loading_frames[next_frame]))
			node.set_meta("loading_frame", next_frame)
		elif node.get_meta("error", false):
			node.set_icon(0, ImageTexture.create_from_image(_icon_error))
			_updating_items.erase(node)
		else:
			sync_node_state(node)
			_updating_items.erase(node)

func _load_item(node: TreeItem) -> void:
	var node_data = _get_node_path_data(node)
	var path: ModSet.ModPath = node_data[0]
	var mod_info: ModInfo = node_data[1]
	var index: ModInfo.IndexFolder = node.get_meta("index_item")
	index.clear()
	mod_info.load_folder(path, index)
	node.remove_meta("loading")
	_lazy_create_tree_items.call_deferred(node)
	_finished_loading_tasks[WorkerThreadPool.get_caller_task_id()] = true

func _preload_mod(node: TreeItem, mod_info: ModInfo) -> void:
	mod_info.load_sources_data()
	_mark_folder(node)
	node.remove_meta("loading")
	_finished_loading_tasks[WorkerThreadPool.get_caller_task_id()] = true

func _ready() -> void:
	create_item()

func _exit_tree() -> void:
	for task_id in _active_loading_tasks:
		WorkerThreadPool.wait_for_task_completion(task_id)

func sync_node_state(node: TreeItem, update_parents: bool = false) -> void:
	if node.has_meta("mod"):
		node.set_icon(0, null)
		return
	var index_node = node.get_meta("index_item")
	var node_name: String = index_node.name
	if index_node is ModInfo.IndexFile and index_node.has_unsaved_shadow:
		node_name = "*" + node_name
	node.set_text(0, node_name)
	node.set_meta("is_unpacked", index_node.is_editable)
	#node.set_icon(0, ImageTexture.create_from_image(_icon_file))
	var icon: ImageTexture = null
	if index_node is ModInfo.IndexFile:
		icon = ImageTexture.create_from_image(
			_icon_file_unpacked if index_node.is_editable 
			else _icon_file_packed
		)
	else:
		icon = ImageTexture.create_from_image(
			_icon_folder_unpacked if index_node.is_editable 
			else _icon_folder_packed
		)
	node.set_icon(0, icon)
	#node.set_custom_color(0, color_packed)
	#node.set_icon(0, ImageTexture.create_from_image(_icon_edit) if index_node.is_editable else null)
	if update_parents and index_node.parent != null and node.get_parent() != null:
		sync_node_state(node.get_parent(), update_parents)

func _build_index(mod_info: ModInfo):
	mod_info.build_index()
	_finished_task_mutex.lock()
	var task_id := _active_tasks[mod_info]
	_finished_task_ids.append(task_id)
	_ready_mods[task_id] = mod_info
	_finished_task_mutex.unlock()

func _mark_folder(node: TreeItem) -> void:
	node.set_meta("lazy_loaded", 0)
	node.set_meta("is_folder", true)
	create_item.call_deferred(node)

func _lazy_create_tree_items(node: TreeItem) -> void:
	#node.remove_child(node.get_child(0))
	var children := []
	var index: ModInfo.IndexFolder = node.get_meta("index_item")
	for folder in index.folders.values():
		children.append([folder, true])
	for file in index.files.values():
		children.append([file, false])

	var comparator := func (c1, c2) -> bool:
		if c1[1] != c2[1]:
			return c1[1]
		var name1: String = c1[0].name
		var name2: String = c2[0].name
		return name1.naturalnocasecmp_to(name2) < 0
		#var is_editable1: bool = c1[0].is_editable
		#var is_editable2: bool = c2[0].is_editable
		#return (is_editable1 and not is_editable2) or (is_editable1 == is_editable2 and name1.naturalnocasecmp_to(name2) < 0)

	children.sort_custom(comparator)
	var create_child := func (item) -> TreeItem:
		var c := node.create_child()
		c.set_meta("index_item", item)
		sync_node_state(c)
		return c

	for i in children:
		var child = i[0]
		var is_folder: bool = i[1]
		var child_node: TreeItem = create_child.call(child)
		if is_folder:
			child_node.set_collapsed_recursive(true)
			_mark_folder(child_node)

func _on_timer_timeout() -> void:
	_update_loading_icons()

func _get_node_path_data(node: TreeItem) -> Array:
	var parts: PackedStringArray = []
	var c := node
	while not c.has_meta("mod"):
		parts.append(c.get_text(0).trim_prefix("*"))
		c = c.get_parent()
	parts.reverse()
	return [ModSet.ModPath.from_parts.bindv(parts.slice(1)).call(parts[0]) if len(parts) > 0 else ModSet.ModPath.ROOT, c.get_meta("mod")]

func _view_item(node: TreeItem, reload: bool) -> void:
	var node_path_data = _get_node_path_data(node)
	_current_file_node = node
	item_viewed.emit(node_path_data[0], node_path_data[1], node.get_meta("index_item"), node, reload)

func _on_file_tree_item_activated() -> void:
	var selected := get_selected()
	if selected == null:
		return
	if selected.get_meta("loading", false) or selected.get_meta("error", false):
		return
	if selected.get_meta("is_folder", false):
		selected.collapsed = not selected.collapsed
	else:
		_view_item(selected, false)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if not (
			event.button_index == MOUSE_BUTTON_RIGHT
			and event.is_released()
		):
			return
		var el := get_item_at_position(event.position)
		if el != null:
			#if el.get_parent().has_meta("mod"):
				#return
			_rmb_item = el
			rmb_menu.clear()
			rmb_menu.size[1] = 1
			if el.has_meta("mod"):
				if not el.get_meta("error", false):
					rmb_menu.add_item("View", RmbActions.VIEW_MODULE)
				if not el.get_meta("loading", false):
					rmb_menu.add_item("Reload", RmbActions.RELOAD_MOD)
					rmb_menu.add_item("Close", RmbActions.CLOSE_MOD)
			else:
				if not el.get_meta("is_folder", false):
					rmb_menu.add_item("View", RmbActions.VIEW)
					rmb_menu.add_item("Reload", RmbActions.RELOAD_FILE)
				if el.get_meta("is_unpacked", false):
					rmb_menu.add_item("Open Containing Folder", RmbActions.SHOW_IN_FILES)
				else:
					if not el.get_meta("is_folder", false):
						rmb_menu.add_item("Unpack", RmbActions.UNPACK)
				rmb_menu.add_item("Copy Path", RmbActions.COPY_PATH)
				#rmb_menu.add_item("Copy", RmbActions.COPY)
			if el.get_meta("is_folder", false):
				rmb_menu.add_item("Reload", RmbActions.RELOAD_FOLDER)
			rmb_menu.position = event.position
			rmb_menu.popup()
	if event.is_action_pressed("refresh"):
		var item := get_selected()
		if item != null and not item.get_meta("loading", false):
			item.collapsed = true
			if item.has_meta("mod"):
				var mod: ModInfo = item.get_meta("mod")
				_load_mod(mod, mod.mod.main_mod.config_path, item)
				return
			if not item.get_meta("is_folder", false):
				item = item.get_parent()
			item.set_meta("lazy_loaded", 1)
			_request_load(item)

func _on_rmb_menu_id_pressed(id: int) -> void:
	match id:
		RmbActions.RELOAD_MOD:
			var mod: ModInfo = _rmb_item.get_meta("mod")
			_rmb_item.collapsed = true
			_rmb_item.select(0)
			_load_mod(mod, mod.mod.main_mod.config_path, _rmb_item)
		RmbActions.CLOSE_MOD:
			_clear_tree(_rmb_item)
			_rmb_item.get_parent().remove_child(_rmb_item)
			mod_closed.emit(_rmb_item.get_meta("mod").mod)
			open_mod_prompt.visible = get_root().get_child_count() == 0
		RmbActions.VIEW:
			_view_item(_rmb_item, false)
		RmbActions.RELOAD_FILE:
			_view_item(_rmb_item, true)
		RmbActions.RELOAD_FOLDER:
			_rmb_item.collapsed = true
			_rmb_item.set_meta("lazy_loaded", 1)
			_request_load(_rmb_item)
		RmbActions.VIEW_MODULE:
			var mod: ModInfo = _rmb_item.get_meta("mod")
			item_viewed.emit(ModSet.ModPath.ROOT, mod, mod.create_config_file_info(), _rmb_item, false)
		RmbActions.UNPACK:
			var node_path_data = _get_node_path_data(_rmb_item)
			var mod: ModInfo = node_path_data[1]
			var index_item : ModInfo.IndexFile = _rmb_item.get_meta("index_item")
			var recent_data = mod.mod.locate_file(node_path_data[0])
			if recent_data == null:
				# TODO warning
				return
			index_item.data = recent_data
			mod.unpack_file(index_item)
			sync_node_state(_rmb_item, true)
		RmbActions.SHOW_IN_FILES:
			var real_path: String = _rmb_item.get_meta("index_item").real_path
			OS.shell_show_in_file_manager(real_path, false)
		RmbActions.COPY_PATH:
			DisplayServer.clipboard_set(_get_node_path_data(_rmb_item)[0].full_path)

func _on_item_collapsed(item: TreeItem) -> void:
	if item.collapsed:
		return
	if item.get_meta("lazy_loaded", 2) == 0:
		item.set_meta("lazy_loaded", 1)
		_request_load(item)

func _finished_task_cleanup() -> void:
	for task_id in _finished_loading_tasks.keys():
		WorkerThreadPool.wait_for_task_completion(task_id)
		_finished_loading_tasks.erase(task_id)
		_active_loading_tasks.erase(task_id)
