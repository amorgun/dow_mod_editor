class_name DisplayErrorPreview extends BasePreview

func process_preview(context: PreviewContext, window: PreviewWindow) -> void:
	if not context.has_error:
		return
	window.set_tab_hidden(PreviewWindow.PreviewTabs.ERROR, false)
	window.set_tab_title(PreviewWindow.PreviewTabs.ERROR, "Error")
