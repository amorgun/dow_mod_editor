class_name ImagePreview extends BasePreview

const extentions := ["tga",	"dds", "png", "bmp", "jpg", "svg"]

func process_preview(context: PreviewContext, _window: PreviewWindow) -> void:
	if context.ext not in extentions:
		return
	var image := context.loader.fload_image(context.file)
	if image.is_empty():
		GsqLogger.warning("Empty image data for %s", [context.file.mod_path])
	context.images['DEFAULT'] = image
	context.has_images = true
