class_name PreviewViewport extends SubViewport

@onready var camera_controller: CameraController = $CameraController
@onready var model: Model = $Model
@onready var ui_screen: UiScreen = $UiScreen

var _camera_configured := false

func setup_model(parser: WhmParser, zoom: float) -> void:
	if not _camera_configured and Settings.data != null:
		_camera_configured = true
		camera_controller.setup_from_lua(Settings.data.pload_lua("data:camera_model.lua"))
	model.setup(parser)
	if parser.bbox != null:
		camera_controller.frame(parser.bbox.to_aabb())
		camera_controller.zoom_distance /= zoom
		camera_controller.save_state()
	ui_screen.hide()
	model.show()

func setup_screen(parser: ScreenParser, size: Vector2i) -> void:
	self.size = size
	ui_screen.size = size
	for c in ui_screen.widget_root.get_children():
		ui_screen.widget_root.remove_child(c)
		c.queue_free()
	parser.setup_view(ui_screen)
	model.hide()
	ui_screen.show()

func screenshot(size: Vector2i) -> Image:
	var update_mode := render_target_update_mode
	var original_size := self.size
	self.size = size
	if ui_screen.visible:
		ui_screen.size = size
	render_target_update_mode = SubViewport.UPDATE_ONCE
	camera_controller.force_update_transform()
	camera_controller.camera.force_update_transform()
	RenderingServer.force_draw()
	var image := get_texture().get_image()
	render_target_update_mode = update_mode
	self.size = original_size
	return image
