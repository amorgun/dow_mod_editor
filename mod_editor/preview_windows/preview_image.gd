class_name ImagePreviewWindow extends VBoxContainer

@onready var image: TextureRect = $Image
#var layers: Dictionary[String, ImageTexture] = {}
@onready var edit: PopupMenu = $Menu/MenuBar/Edit

enum EditCommands {
	FLIP = 0,
}

var layer_images: Dictionary[int, ImageTexture] = {}

func _on_edit_id_pressed(id: int) -> void:
	match id:
		EditCommands.FLIP:
			image.flip_v = not image.flip_v
			edit.set_item_checked(EditCommands.FLIP, image.flip_v)
		_:
			if id in layer_images:
				for k in layer_images:
					edit.set_item_checked(k, k == id)
				image.texture = layer_images[id]

func set_images(images: Dictionary[String, Image]) -> void:
	edit.clear()
	edit.add_check_item("Flip", EditCommands.FLIP)
	var first_layer_name: String = images.keys()[0]
	image.texture = ImageTexture.create_from_image(images[first_layer_name])
	
	if len(images) > 1:
		edit.add_separator("Layers")
		for layer_name in images:
			edit.add_radio_check_item(layer_name)
			edit.set_item_checked(-1, layer_name == first_layer_name)
			layer_images[edit.get_item_id(edit.item_count - 1)] = ImageTexture.create_from_image(images[layer_name])
