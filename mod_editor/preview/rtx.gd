class_name RtxPreview extends BasePreview

const extentions := ["rtx"]
var parser := RtxParser.new()

func process_preview(context: PreviewContext, _window: PreviewWindow) -> void:
	if context.ext not in extentions:
		return
	var image := parser.parse(context.file.read_bytes())
	if image == null:
		context.has_error = true
		return
	if image.is_empty():
		GsqLogger.warning("Empty image data for %s", [context.file.mod_path])
	context.images['DEFAULT'] = image
	context.has_images = true
