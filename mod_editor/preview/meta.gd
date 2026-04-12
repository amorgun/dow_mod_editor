class_name MetaPreview extends BasePreview

func process_preview(context: PreviewContext, window: PreviewWindow) -> void:
	window.set_tab_hidden(PreviewWindow.PreviewTabs.META, false)
	window.set_tab_title(PreviewWindow.PreviewTabs.META, "Meta")
	var meta = {}
	meta["sources"] = []
	for s in context.mod.get_all_file_locations(context.mod_path.root_folder, context.mod_path.path):
		meta["sources"].append(s.source.effective_path)
	meta["modified"] = Time.get_datetime_string_from_unix_time(context.index_file.modified_time)
	if context.index_file.has_shadow:
		meta["shadow"] = {
			"path": context.index_file.shadow_path,
			"modified": Time.get_datetime_string_from_unix_time(FileAccess.get_modified_time(context.index_file.shadow_path)),
		}
	window.meta_content.text = SimpleLua.stringify(meta, "  ", "meta = ", false)
	window.meta_content.syntax_highlighter = LuaSyntaxHighlighter.new()
