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

static var _virtual_height := 0.0

## Fonts and pixel sizes are authored for a constant viewport height; render
## the screen's 2D content at it (size_2d_override) and stretch to fit.
func _apply_screen_override(target: Vector2i) -> void:
	if _virtual_height == 0.0 and Settings.data != null:
		_virtual_height = Settings.data.pload_lua("data:screen_editor.lua").get_value("viewport_height", 768.0, TYPE_FLOAT)
	if _virtual_height > 0 and target.y > 0:
		size_2d_override = Vector2i(Vector2(target) * (_virtual_height / target.y))
		size_2d_override_stretch = true
		ui_screen.size = size_2d_override
	else:
		ui_screen.size = target

func setup_screen(parser: ScreenParser, size: Vector2i) -> void:
	self.size = size
	_apply_screen_override(size)
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
		_apply_screen_override(size)
	render_target_update_mode = SubViewport.UPDATE_ONCE
	camera_controller.force_update_transform()
	camera_controller.camera.force_update_transform()
	RenderingServer.force_draw()
	var image := get_texture().get_image()
	render_target_update_mode = update_mode
	self.size = original_size
	if ui_screen.visible:
		_apply_screen_override(original_size)
	return image
