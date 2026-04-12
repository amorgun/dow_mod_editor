extends PopupMenu

@onready var about_popup: Popup = $AboutPopup


func _on_about_popup_close_requested() -> void:
	about_popup.hide()

func _on_id_pressed(id: int) -> void:
	match id:
		0:
			about_popup.show()
		1:
			OS.shell_show_in_file_manager(
				ProjectSettings.globalize_path(
					ProjectSettings.get_setting("debug/file_logging/log_path")
				),
				false,
			)

func _on_about_label_meta_clicked(meta: Variant) -> void:
	OS.shell_open(meta)
