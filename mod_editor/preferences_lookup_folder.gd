class_name LookupFolder extends HBoxContainer

@onready var path: LineEdit = $Path
@onready var file_dialog: FileDialog = $FileDialog


func _on_remove_button_pressed() -> void:
	queue_free()

func _pick_folder() -> void:
	file_dialog.current_path = Settings.expand_path(path.text)
	print(file_dialog.current_path)
	file_dialog.popup_centered()

func _on_file_dialog_dir_selected(dir: String) -> void:
	path.text = dir
