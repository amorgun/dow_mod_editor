extends SplitContainer
@onready var preview_windows: TabContainer = $PreviewWindows
@onready var preview_window_tpl: PreviewWindow = $PreviewWindows/PreviewWindow
@onready var file_tree: FileTree = $FileTree

var current_preview: PreviewWindow:
	get: return preview_windows.get_child(preview_windows.current_tab) if preview_windows.current_tab > 0 else null

var meta_previewer := MetaPreview.new()
var compiled_text_previewer := DisplayCompiledTextPreview.new()
var previewers: Array[BasePreview] = [
	LuaPreview.new(),
	TextPreview.new(),
	UcsPreview.new(),
	RgdPreview.new(),
	WhmPreview.new(),
	WhePreview.new(),
	#SgbPreview.new(),
	RtxPreview.new(),
	RshPreview.new(),
	WtpPreview.new(),
	ImagePreview.new(),
	CompiledTextPreview.new(),
	ShadowPreview.new(),
	ChunkyPreview.new(),
	meta_previewer,
	DisplayErrorPreview.new(),
	DisplayTextPreview.new(),
	compiled_text_previewer,
	DisplayModelPreview.new(),
	DisplayImagesPreview.new(),
]

func _ready() -> void:
	for tab_idx in preview_windows.get_tab_count():
		preview_windows.set_tab_hidden(tab_idx, true)
	for p in previewers:
		p.prepare()

func _on_file_tree_item_viewed(path: ModSet.ModPath, mod_info: ModInfo, index_file: ModInfo.IndexFile, tree_item: TreeItem, reload: bool) -> void:
	var preview: PreviewWindow = null
	var has_existing_preview: bool = tree_item.has_meta("preview")

	if not path.is_root() and (reload or not has_existing_preview):
		var index_item : ModInfo.IndexFile = tree_item.get_meta("index_item")
		var recent_data = mod_info.mod.locate_file(path)
		if recent_data == null:
			GsqLogger.error("Cannot find %s", [path])
			return
		index_item.data = recent_data
		file_tree.sync_node_state(tree_item, true)
	var active_tab: int = -1
	if has_existing_preview:
		preview = tree_item.get_meta("preview")
		active_tab = preview.current_tab
		preview_windows.move_child(preview, -1)
	else:
		preview = preview_window_tpl.duplicate(DuplicateFlags.DUPLICATE_SCRIPTS | DuplicateFlags.DUPLICATE_SIGNALS)
		tree_item.set_meta("preview", preview)
		preview_windows.add_child(preview)
		preview.clear_tabs()
		preview.text_content.text_autosave.connect(_on_text_autosave.bind(preview))
		preview.text_content.text_manual_save.connect(_on_text_manual_save.bind(preview))
		preview.text_content.reload_from_compiled.connect(_on_text_reload.bind(preview))
		if preview_windows.get_child_count() - 1 > Settings.max_preview_tabs:
			var removed: PreviewWindow = preview_windows.get_child(1)
			removed.context.tree_item.remove_meta("preview")
			preview_windows.remove_child(removed)
			removed.queue_free()
	if reload or not has_existing_preview:
		var preview_context := PreviewContext.new()
		preview_context.mod_info = mod_info
		preview_context.index_file = index_file
		preview_context.tree_item = tree_item
		preview_context.ext = path.get_extension().to_lower() if not path.is_root() else "module"
		preview.context = preview_context
		preview_windows.move_child(preview, -1)
		for c in previewers:
			c.process_preview(preview_context, preview)
		if has_existing_preview:
			preview.current_tab = active_tab
		else:
			for tab_idx in PreviewWindow.PreviewTabs.values():
				if not preview.is_tab_hidden(tab_idx):
					preview.current_tab = tab_idx
					break
	preview.visible = true

func _on_text_autosave(preview: PreviewWindow) -> void:
	preview.process_text_autosave()
	meta_previewer.process_preview(preview.context, preview)
	file_tree.sync_node_state(preview.context.tree_item)

func _on_text_manual_save(preview: PreviewWindow) -> void:
	preview.process_text_manual_save()
	meta_previewer.process_preview(preview.context, preview)
	compiled_text_previewer.process_preview(preview.context, preview)
	file_tree.sync_node_state(preview.context.tree_item)

func _on_text_reload(preview: PreviewWindow) -> void:
	preview.text_content.text = preview.context.compiled_text
	preview.text_content.push_autosave()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("refresh"):
		var preview := current_preview
		if preview == null:
			return
		var context := preview.context
		if context.tree_item != null:
			_on_file_tree_item_viewed(context.mod_path, context.mod_info, context.index_file, context.tree_item, true)
