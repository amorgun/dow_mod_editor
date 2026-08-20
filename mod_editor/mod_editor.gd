class_name ModEditor extends Control

@onready var file_dialog: FileDialog = $FileDialog
@onready var file_tree: FileTree = $SplitContainer/VSplitMessages/FileBrowser/FileTree
@onready var preferences_popup: Window = $SplitContainer/MenuBar/Edit/PreferencesPopup
@onready var mod_editor: SplitContainer = $SplitContainer
@onready var screen_editor: ScreenEditor = $ScreenEditor

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
	Core.open_mod(mod_path)

func _ready() -> void:
	if Settings.save_history:
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
	if Core.get_mod(path) == null:
		load_mod(path)
	if Settings.save_history:
		var config := Settings.get_config()
		var mod_list: Array = config.get_value("history", "mod_list", [])
		mod_list.append(path)
		config.set_value("history", "mod_list", mod_list)
		config.save(Settings.config_path)

func _on_mod_closed(mod: ModSet) -> void:
	var mod_path := mod.main_mod.config_path
	Core.close_mod(mod_path)
	if Settings.save_history:
		var config := Settings.get_config()
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

func _on_screen_editor_open(content: String, loader: ModResourceLoader, mod_info: ModInfo) -> void:
	screen_editor.visible = true
	mod_editor.visible = false
	screen_editor.setup_content(content, loader, mod_info)

func _on_screen_editor_close() -> void:
	screen_editor.visible = false
	mod_editor.visible = true
