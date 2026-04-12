class_name TextPreviewWindow extends VBoxContainer
@onready var timer: Timer = $Timer
@onready var text_node: CodeEdit = $Text

var initialized := false

enum EDIT_IDS {
	COLLAPSE_ALL = 0,
	UNCOLLAPSE_ALL = 1,
	SAVE = 2,
	RELOAD = 4,
}

var text: String:
	set(s): 		
		text_node.text = s
		if not initialized:
			text_node.clear_undo_history()
			initialized = true
	get: return text_node.text
		
signal text_autosave()
signal text_manual_save()
signal reload_from_compiled()

func _on_text_changed() -> void:
	timer.start()

func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("save_text"):
		push_autosave()
		text_manual_save.emit()
		accept_event()

func _on_timer_timeout() -> void:
	text_autosave.emit()

func push_autosave() -> void:
	if not timer.is_stopped():
		timer.stop()
	text_autosave.emit()

func _on_edit_id_pressed(id: int) -> void:
	match id:
		EDIT_IDS.COLLAPSE_ALL:
			text_node.fold_all_lines()
		EDIT_IDS.UNCOLLAPSE_ALL:
			text_node.unfold_all_lines()
		EDIT_IDS.SAVE:
			push_autosave()
			text_manual_save.emit()
		EDIT_IDS.RELOAD:
			reload_from_compiled.emit()
