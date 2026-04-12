extends Window
@onready var tab_container: TabContainer = $HBoxContainer/VSplitContainer/TabContainer
@onready var tab_buttons: VBoxContainer = $HBoxContainer/VSplitContainer/Buttons
const BUTTONS_GROUP = preload("uid://f6d83aqhyqfw")

@onready var config_mod: OptionButton = $HBoxContainer/VSplitContainer/TabContainer/General/GridContainer/ConfigMod/Value
@onready var num_last_tabs: SpinBox = $HBoxContainer/VSplitContainer/TabContainer/General/GridContainer/LastTabs/Value
@onready var shadow_folder: LineEdit = $HBoxContainer/VSplitContainer/TabContainer/General/GridContainer/ShadowFolder
@onready var lookup_folders: VBoxContainer = $HBoxContainer/VSplitContainer/TabContainer/General/GridContainer/LookupFolders
@onready var lookup_folder_template: LookupFolder = $HBoxContainer/VSplitContainer/TabContainer/General/GridContainer/LookupFolders/Template

@onready var blender_path: LineEdit = $HBoxContainer/VSplitContainer/TabContainer/Tools/GridContainer/Panel/BlenderPath
@onready var blender_file_dialog: FileDialog = $HBoxContainer/VSplitContainer/TabContainer/Tools/GridContainer/Panel/BlenderFileDialog
@onready var blender_check_popup: Popup = $HBoxContainer/VSplitContainer/TabContainer/Tools/GridContainer/Panel/CheckPopup
@onready var blender_check_result: RichTextLabel = $HBoxContainer/VSplitContainer/TabContainer/Tools/GridContainer/Panel/CheckPopup/MarginContainer/CheckResult


signal open_config_mod()

func _ready() -> void:
	for c in tab_container.get_children():
		var button := Button.new()
		button.text = c.name
		button.toggle_mode = true
		button.button_group = BUTTONS_GROUP
		tab_buttons.add_child(button)
		button.pressed.connect(_on_tab_change.bind(c.get_index()))
	tab_buttons.get_child(0).button_pressed = true
	if OS.has_feature("windows"):
		blender_file_dialog.filters = ["*.exe"]

func load_state() -> void:
	var config := Settings.get_config()
	var current_config_mod: String = config.get_value("global", "currentmoddc")
	config_mod.clear()
	for f in DirAccess.get_files_at(Settings.config_path.get_base_dir()):
		if f.to_lower().ends_with(".module"):
			config_mod.add_item(f.trim_suffix(".module"))
	for i in config_mod.item_count:
		if config_mod.get_item_text(i) == current_config_mod:
			config_mod.select(i)
			break
	config_mod.get_popup().always_on_top = true
	num_last_tabs.value = config.get_value("global", "max_preview_tabs", 1)
	shadow_folder.text = config.get_value("global", "shadow_folder", "")
	for i in lookup_folders.get_child_count() - 2:
		lookup_folders.remove_child(lookup_folders.get_child(1))
	for f in config.get_value("global", "extra_lookup_folders", []):
		var child := lookup_folder_template.duplicate(DuplicateFlags.DUPLICATE_SCRIPTS | DuplicateFlags.DUPLICATE_SIGNALS)
		lookup_folders.add_child(child)
		lookup_folders.move_child(child, -2)
		child.path.text = f
		child.visible = true
	blender_path.text = config.get_value("global", "blender_path", "")

func save_state():
	var config := Settings.get_config()
	config.set_value("global", "currentmoddc", config_mod.get_item_text(config_mod.selected))
	config.set_value("global", "max_preview_tabs", num_last_tabs.value)
	config.set_value("global", "shadow_folder", shadow_folder.text.strip_edges())
	var extra_lookup_folders: Array = []
	for i in lookup_folders.get_child_count() - 2:
		var path: String = lookup_folders.get_child(i + 1).path.text.strip_edges()
		if len(path) > 0:
			extra_lookup_folders.append(path)
	config.set_value("global", "extra_lookup_folders", extra_lookup_folders)
	config.set_value("global", "blender_path", blender_path.text.strip_edges())
	Settings.blender_path = blender_path.text.strip_edges()
	config.save(Settings.config_path)

func open() -> void:
	tab_container.get_child(0).visible = true
	tab_buttons.get_child(0).button_pressed = true
	load_state()
	popup_centered()

func _on_save() -> void:
	save_state()
	hide()

func _on_close() -> void:
	hide()

func _on_tab_change(tab_id: int) -> void:
	tab_container.get_child(tab_id).visible = true

func _on_add_extra_path() -> void:
	var child := lookup_folder_template.duplicate(DuplicateFlags.DUPLICATE_SCRIPTS | DuplicateFlags.DUPLICATE_SIGNALS)
	lookup_folders.add_child(child)
	lookup_folders.move_child(child, -2)
	child.visible = true

func _on_open_config_folder_pressed() -> void:
	OS.shell_show_in_file_manager(
		ProjectSettings.globalize_path(Settings.config_path),
		false,
	)

func _on_open_config() -> void:
	hide()
	open_config_mod.emit()

func _on_select_blender_path() -> void:
	blender_file_dialog.popup_centered()
	blender_file_dialog.current_file = blender_path.text

func _on_filedialog_select_blender_path(path: String) -> void:
	blender_path.text = path

func _on_test_blender_button_pressed() -> void:
	var blender := Blender.new(blender_path.text.strip_edges())
	if blender.check():
		blender_check_result.text = "All fine!"
	else:
		blender_check_result.text = blender.last_check_error
	blender_check_popup.popup()
