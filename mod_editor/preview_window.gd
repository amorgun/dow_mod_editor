class_name PreviewWindow extends TabContainer
@onready var text_content: TextPreviewWindow = $Text
@onready var compiled_text_content: TextPreviewWindow = $Compiled
@onready var image_content: ImagePreviewWindow = $Image
@onready var model_content: ModelPreviewWindow = $Model
#@onready var map: Node3D = $MarginContainer/SubViewportContainer/SubViewport/Map
@onready var chunky_content: ChunkyPreviewWindow = $Chunky
@onready var meta_content: TextEdit = $Meta

signal saved(preview: PreviewWindow)

enum PreviewTabs {
	ERROR,
	MODEL,
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

var context: PreviewContext
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
