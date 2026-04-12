class_name ModelPreviewWindow extends VBoxContainer

@onready var camera_controller: CameraController = $MarginContainer/SubViewportContainer/SubViewport/CameraController
@onready var model: Model = $MarginContainer/SubViewportContainer/SubViewport/Model
@onready var viewport: SubViewportContainer = $MarginContainer/SubViewportContainer
@onready var menu_button: MenuButton = $MarginContainer/SubViewportContainer/SubViewport/MenuButton
@onready var camera_timer: Timer = $MarginContainer/SubViewportContainer/CameraTimer
@onready var camera_config := Settings.data.pload_lua("data:camera_model.lua")
var is_hovered := false
var is_focused := false

signal open_in_blender

enum EditCommands {
	OPEN_IN_BLENDER = 0,
	RESSET_CAMERA = 1,
}

func _ready() -> void:
	menu_button.get_popup().id_pressed.connect(_on_edit_id_pressed)
	$"/root/ModEditor".mouse_move.connect(camera_controller._on_root_mouse_move)
	viewport.stretch = not viewport.stretch  # Fix warning when duplicating a viewport with stretch=True
	camera_controller.setup_from_lua(camera_config)

func _on_focus_entered() -> void:
	#camera_controller.process_input = true
	is_focused = true

func _on_focus_exited() -> void:
	#camera_controller.process_input = false
	is_focused = false

func _on_mouse_entered() -> void:
	is_hovered = true
	camera_controller.process_input = true

func _on_mouse_exited() -> void:
	if camera_controller.is_rotating:
		camera_timer.start()
	else:
		camera_controller.process_input = false
	is_hovered = false

func _notification(what):
	if what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT:
		camera_controller.process_input = false
		camera_controller.stop_rotating()
	if what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN:
		if is_visible_in_tree() and focus_entered:
			camera_controller.process_input = true

func _on_edit_id_pressed(id: int) -> void:
	match id:
		EditCommands.OPEN_IN_BLENDER:
			open_in_blender.emit()
		EditCommands.RESSET_CAMERA:
			camera_controller.restore_state()

func _on_camera_check() -> void:
	if not camera_controller.is_rotating:
		camera_controller.process_input = is_hovered
		camera_timer.stop()
