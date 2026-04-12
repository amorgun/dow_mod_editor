extends Control

var loaded_mods = {};
@onready var file_dialog: FileDialog = $FileDialog
@onready var file_tree: FileTree = $SplitContainer/VSplitMessages/FileBrowser/FileTree
@onready var preferences_popup: Window = $SplitContainer/MenuBar/Edit/PreferencesPopup

signal mouse_move(event: InputEventMouseMotion)

enum FileActions {
	NEW = 0,
	OPEN = 1,
	EXIT = 2,
}

enum EditActions {
	PREFERENCES = 0,
}

func load_mod(mod_path: String):
	GsqLogger.info('Load %s' % mod_path)
	var mod: ModSet = file_tree.add_mod(mod_path)
	if mod != null:
		loaded_mods[mod_path] = mod

func _ready() -> void:
	var config := Settings.get_config()
	var mod_list: PackedStringArray = config.get_value("history", "mod_list", [])
	for mod_path in mod_list:
		load_mod(mod_path)
	get_window().size = Settings.window_size

func _on_file_id_pressed(id: int) -> void:
	match id:
		FileActions.OPEN:
			var config := Settings.get_config()
			file_dialog.current_dir = config.get_value("history", "game_folder", "")
			file_dialog.popup_centered()
		FileActions.EXIT:
			get_tree().quit()

func _on_mod_file_selected(path: String) -> void:
	var config := Settings.get_config()
	var mod_list: Array = config.get_value("history", "mod_list", [])
	if path not in loaded_mods:
		mod_list.append(path)
		load_mod(path)
	config.set_value("history", "mod_list", mod_list)
	config.save(Settings.config_path)

func _on_mod_closed(mod: ModSet) -> void:
	var config := Settings.get_config()
	var mod_path := mod.main_mod.config_path
	loaded_mods.erase(mod_path)
	var mod_list: Array = config.get_value("history", "mod_list", [])
	mod_list.remove_at(mod_list.find(mod_path))
	config.set_value("history", "mod_list", mod_list)
	config.save(Settings.config_path)

func _on_edit_id_pressed(id: int) -> void:
	match id:
		EditActions.PREFERENCES:
			preferences_popup.open()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_move.emit(event)

func _on_preferences_open_config_mod() -> void:
	_on_mod_file_selected(Settings.config_module_path)
