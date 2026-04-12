class_name DisplayTextPreview extends BasePreview

func process_preview(context: PreviewContext, window: PreviewWindow) -> void:
	if not context.has_text:
		return
	window.set_tab_hidden(PreviewWindow.PreviewTabs.TEXT, false)
	window.set_tab_title(PreviewWindow.PreviewTabs.TEXT, "Content")
	window.add_initializer(PreviewWindow.PreviewTabs.TEXT, set_text)

func set_text(context: PreviewContext, window: PreviewWindow) -> void:
	# TODO preview.text_content.syntax_highlighter
	if context.text_highlight == PreviewContext.TextHighlight.LUA:
		window.text_content.text_node.syntax_highlighter = LuaSyntaxHighlighter.new()
	window.text_content.text = context.text
