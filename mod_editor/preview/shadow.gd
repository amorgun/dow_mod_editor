class_name ShadowPreview extends BasePreview

func process_preview(context: PreviewContext, _window: PreviewWindow) -> void:
	if not context.index_file.has_shadow:
		return
	var shadow_path := context.index_file.shadow_path
	if not FileAccess.file_exists(shadow_path):
		return
	context.text = FileAccess.open(shadow_path, FileAccess.READ).get_as_text()
