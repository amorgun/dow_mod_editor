## Draws the screen's ruler guides over the canvas.
class_name GuideLines extends Control

const COLOR := Color(0.2, 0.8, 0.9, 0.7)

var screen: UiScreen = null

func _draw() -> void:
	if screen == null:
		return
	for g in screen.guides:
		if g is not Dictionary:
			continue
		var pos := float(g.get("position", 0.0))
		if bool(g.get("horizontal", false)):
			draw_line(Vector2(0, pos * size.y), Vector2(size.x, pos * size.y), COLOR)
		else:
			draw_line(Vector2(pos * size.x, 0), Vector2(pos * size.x, size.y), COLOR)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
