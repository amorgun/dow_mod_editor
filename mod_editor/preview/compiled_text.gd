class_name CompiledTextPreview extends BasePreview

func process_preview(context: PreviewContext, _window: PreviewWindow) -> void:
	context.compiled_text = context.text
	context.has_compiled_text = context.has_text
