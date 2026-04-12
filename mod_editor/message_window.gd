class_name MessagesList extends FoldableContainer

@onready var messages: VBoxContainer = $ScrollContainer/Messages
@onready var item_temmplate: RichTextLabel = $ScrollContainer/Messages/ItemTemmplate
@export var max_messages := 2
var orig_title := ""

func _ready() -> void:
	# TODO use Godot logging
	GsqLogger.message_added.connect(add_message)
	orig_title = title

func _on_folding_changed(now_folded: bool) -> void:
	size_flags_vertical = Control.SIZE_SHRINK_END if now_folded else Control.SIZE_EXPAND_FILL
	get_parent().dragging_enabled = not now_folded
	title = orig_title
	
func add_message(text: String, level: Logging.LogLevel):
	visible = true
	var message := item_temmplate.duplicate()
	message.text = "%s: %s" % [Logging.LogLevel.find_key(level), text]
	message.visible = true
	if folded:
		title = message.text
	messages.add_child(message)
	messages.move_child(message, 0)
	if messages.get_child_count() > max_messages + 1:
		messages.get_child(messages.get_child_count() - 2).queue_free()
