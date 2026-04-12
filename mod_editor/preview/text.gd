class_name TextPreview extends BasePreview

const extentions := ["txt", "ini", "module", "terrainmaterial", "json"]

func process_preview(context: PreviewContext, window: PreviewWindow) -> void:
	if context.ext not in extentions:
		return
	context.text = context.bytes.get_string_from_utf8()
	context.has_text = true
	if not window.saved.is_connected(on_save):
		window.saved.connect(on_save)

func on_save(preview: PreviewWindow) -> void:
	var context := preview.context
	var tgd_filepath := context.index_file.real_path
	var file := FileAccess.open(tgd_filepath, FileAccess.WRITE)
	if file == null:
		GsqLogger.error("Cannnot open %s", [tgd_filepath])
		return
	file.store_string(preview.text_content.text)
	file.flush()
	context.compiled_text = context.file.read_bytes().get_string_from_utf8()
