class_name PreviewWindow extends TabContainer
@onready var text_content: TextPreviewWindow = $Text
@onready var compiled_text_content: TextPreviewWindow = $Compiled
@onready var image_content: ImagePreviewWindow = $Image
@onready var model_content: ModelPreviewWindow = $Model
@onready var screen_content: ScreenPreviewWindow = $Screen

#@onready var map: Node3D = $MarginContainer/SubViewportContainer/SubViewport/Map
@onready var chunky_content: ChunkyPreviewWindow = $Chunky
@onready var meta_content: TextEdit = $Meta

signal saved(preview: PreviewWindow)
signal screen_editor_opened(content: String, loader: ModResourceLoader, mod_info: ModInfo)
signal script_running_changed(running: bool)

enum PreviewTabs {
	ERROR,
	MODEL,
	SCREEN,
	#MAP,
	TEXT,
	COMPILED_TEXT,
	IMAGE,
	LINKS,
	CHUNKY,
	META,
}

var deferred_initializers: Dictionary[PreviewTabs, Array] = {}
var initialized_tabs: Dictionary[PreviewTabs, bool] = {}

var context: FileData
var file: ModSet.FilePath:
	get: return context.file if context != null else null

func clear_tabs() -> void:
	text_content.push_autosave()
	for tab_idx in get_tab_count():
		set_tab_hidden(tab_idx, true)

func process_text_autosave() -> void:
	var shadow_path := context.index_file.shadow_path
	DirAccess.make_dir_recursive_absolute(shadow_path.get_base_dir())
	FileAccess.open(shadow_path, FileAccess.WRITE).store_string(text_content.text)

func process_text_manual_save() -> void:
	if context.file.packed:
		context.mod_info.unpack_file(context.index_file)
	saved.emit(self)

func add_initializer(tab: PreviewTabs, fn: Callable) -> void:
	deferred_initializers.get_or_add(tab, []).append(fn)

func _on_tab_changed(tab: PreviewTabs) -> void:
	for fn: Callable in deferred_initializers.get(tab, []):
		fn.call(context, self)
	deferred_initializers.erase(tab)

func _on_screen_editor_open() -> void:
	screen_editor_opened.emit(context.text, context.loader, context.mod_info)

var _lua_env: LuaApiEnv

func _on_run_lua() -> void:
	if _lua_env != null:
		return
	_lua_env = LuaApiEnv.new(Core, context.index_file.mod)
	_lua_env.interruptible = true
	text_content.set_running(true)
	script_running_changed.emit(true)
	var result: CoreApi.Result = await Core.execute_lua(context.index_file, _lua_env)
	_lua_env = null
	text_content.set_running(false)
	script_running_changed.emit(false)
	if not result.ok:
		GsqLogger.error("%s", [result.error])
	elif result.data.get("return") != null:
		GsqLogger.print("Script returned: %s", [str(result.data["return"])])

func _on_stop_lua() -> void:
	if _lua_env != null:
		_lua_env.cancel()
