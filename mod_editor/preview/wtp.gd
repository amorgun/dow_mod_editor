class_name WtpPreview extends BasePreview

var parser := WtpParser.new()	

func process_preview(context: PreviewContext, _window: PreviewWindow) -> void:
	if context.ext != "wtp":
		return
	var result := parser.parse(context.file.read_bytes())
	if result == null:
		context.has_error = true
		return
	context.images = {}
	for channel_name: String in WtpParser.Channel:
		var channel: WtpParser.Channel = WtpParser.Channel.get(channel_name)
		if channel not in result.channels:
			continue
		context.images[channel_name.capitalize()] = result.channels[channel]
	context.has_images = len(context.images) > 0
