class_name DisplayModelPreview extends BasePreview

func process_preview(context: PreviewContext, window: PreviewWindow) -> void:
	if not context.has_model:
		return
	window.set_tab_hidden(PreviewWindow.PreviewTabs.MODEL, false)
	window.set_tab_title(PreviewWindow.PreviewTabs.MODEL, "Preview")
	window.model_content.model.show()
	#window.map.hide()
	window.model_content.viewport.grab_focus()
