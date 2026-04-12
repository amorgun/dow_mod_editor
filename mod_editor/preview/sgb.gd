class_name SgbPreview extends BasePreview

func can_preview(path: String) -> bool:
	return path.get_extension().to_lower() == 'sgb'

func setup_preview(preview: PreviewWindow) -> void:
	super(preview)
	preview.set_tab_hidden(PreviewWindow.PreviewTabs.MODEL, false)
	preview.set_tab_title(PreviewWindow.PreviewTabs.MODEL, 'Preview')
	preview.current_tab = PreviewWindow.PreviewTabs.MODEL
	preview.model.hide()
	var map := preview.map
	map.show()
	var data = preview.file.read_bytes()
	var mod := preview.file.source.mod_set
	var parser := SgbParser.create(mod)
	var ground_file := mod.locate_data(preview.file.mod_path.get_basename() + '.tga')
	parser.parse(data, ground_file.read_image())
	parser.setup_map(map)
	preview.viewport_3d.grab_focus()
	
