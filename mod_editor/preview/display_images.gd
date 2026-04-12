class_name DisplayImagesPreview extends BasePreview


func process_preview(context: PreviewContext, window: PreviewWindow) -> void:
	if not context.has_images:
		return
	window.set_tab_hidden(PreviewWindow.PreviewTabs.IMAGE, false)
	window.set_tab_title(PreviewWindow.PreviewTabs.IMAGE, "Content")
	window.image_content.set_images(context.images)
