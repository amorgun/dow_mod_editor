class_name PreviewContext

enum TextHighlight {
	NONE,
	LUA,
}

var index_file: ModInfo.IndexFile
var file: ModSet.FilePath:
	get: return index_file.data
var mod_info: ModInfo
var mod: ModSet:
	get: return mod_info.mod
var loader: ModResourceLoader:
	get: return mod_info.loader
var mod_path: ModSet.ModPath:
	get: return file.mod_path

var tree_item: TreeItem
#var path: String
var ext: String

var has_error := false

var has_text := false
var text: String
var text_highlight := TextHighlight.NONE

var has_compiled_text := false
var compiled_text: String

var has_model := false

var images: Dictionary[String, Image]
var has_images := false

var _has_bytes:= false
var _bytes: PackedByteArray = []

var bytes: PackedByteArray:
	get:
		if not _has_bytes:
			_bytes = file.read_bytes()
		return _bytes

#func cleanup() -> void:
	#text = ""
	#compiled_text = ""
	#_bytes = []
	#print("Cleanup")
