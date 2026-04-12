class_name DisplayCompiledTextPreview extends BasePreview

func process_preview(context: PreviewContext, window: PreviewWindow) -> void:
	if not context.has_compiled_text:
		return
	window.set_tab_hidden(PreviewWindow.PreviewTabs.COMPILED_TEXT, false)
	window.set_tab_title(PreviewWindow.PreviewTabs.COMPILED_TEXT, "Compiled")
	window.add_initializer(PreviewWindow.PreviewTabs.COMPILED_TEXT, set_compiled_text)

func set_compiled_text(context: PreviewContext, window: PreviewWindow) -> void:
	# TODO preview.text_content.syntax_highlighter
	window.compiled_text_content.text = context.compiled_text
	if context.text_highlight == PreviewContext.TextHighlight.LUA:
		window.compiled_text_content.text_node.syntax_highlighter = LuaSyntaxHighlighter.new()
