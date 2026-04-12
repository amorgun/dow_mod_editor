class_name WhePreview extends BasePreview

var parser: Whe.Parser= Whe.Parser.new()
const DATA_KEY = "data"


func process_preview(context: PreviewContext, window: PreviewWindow) -> void:
	if context.ext != "whe":
		return
	context.text = SimpleLua.stringify(parser.parse_file(context.file), '\t', '%s = ' % DATA_KEY, false)
	context.has_text = true
	context.text_highlight = PreviewContext.TextHighlight.LUA
	if not window.saved.is_connected(on_save):
		window.saved.connect(on_save)

func on_save(preview: PreviewWindow) -> void:
	var context := preview.context
	var lua := Lua.new()
	var err := lua.dostring(preview.text_content.text)
	if err != Error.OK:
		GsqLogger.error('Cannot parse file "%s":\n%s' % [context.mod_path, lua.get_error()])
		return
	var val = lua.get_value(DATA_KEY)
	if typeof(val) != TYPE_DICTIONARY:
		GsqLogger.error('Cannot parse file "%s":\nKey "%s" has a wrong type %s' % [context.path, DATA_KEY, type_string(typeof(val))])
		return
	var writer := Whe.Writer.new()
	writer.write_file(val, context.file.real_path)
	context.compiled_text = SimpleLua.stringify(parser.parse_file(context.file), '\t', '%s = ' % DATA_KEY, false)
