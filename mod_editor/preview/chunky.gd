class_name ChunkyPreview extends BasePreview

func process_preview(context: PreviewContext, window: PreviewWindow) -> void:
	if not ChunkReader.is_chunky(context.bytes):
		return
	window.set_tab_hidden(PreviewWindow.PreviewTabs.CHUNKY, false)
	window.set_tab_title(PreviewWindow.PreviewTabs.CHUNKY, "Chunky")
	window.add_initializer(PreviewWindow.PreviewTabs.CHUNKY, set_chunky)

func set_chunky(context: PreviewContext, window: PreviewWindow) -> void:
	var preview := window.chunky_content
	var root := preview.set_data(context.bytes)
	if root == null: return
	root.set_collapsed_recursive(true)
	root.collapsed = false
	preview.view_item(root.get_child(0))
