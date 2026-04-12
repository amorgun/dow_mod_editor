class_name WhmPreview extends BasePreview

func process_preview(context: PreviewContext, window: PreviewWindow) -> void:
	if context.ext != "whm":
		return
	var model: Model = window.model_content.model
	var parser := WhmParser.create(context.file.source.mod_set)
	model.reset()
	parser.parse(context.bytes)
	parser.setup_model(model)
	if parser.bbox != null:
		window.model_content.camera_controller.frame(parser.bbox.to_aabb())
		window.model_content.camera_controller.save_state()
	context.has_model = true
	window.model_content.open_in_blender.connect(open_on_blender.bind(
		context.mod_path.path,
		context.mod_info._unpacked_sources[
			context.file.source.root_folder_name
		].effective_path.get_base_dir(),  # FIXME this is horrible
	))

func open_on_blender(model_path: String, mod_dir: String) -> void:
	var blender := Blender.new(Settings.blender_path)
	if not blender.check():
		GsqLogger.error("Blender is not configured. Go to Edit -> Preferences -> Tools to fix it")
		return
	blender.open_model(model_path, mod_dir)
