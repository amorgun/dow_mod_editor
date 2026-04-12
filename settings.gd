class_name ModViewerSettings extends Node

var config_module_path: String = ""
var shadow_folder: String = "_SHADOW"
var blender_path: String = ""
var config_path: String = ""
var window_size: Vector2i
var extra_lookup_folders: PackedStringArray = []
var max_preview_tabs: int = 0
var data: ModResourceLoader


func get_config() -> ConfigFile:
	var config = ConfigFile.new()
	if not FileAccess.file_exists(Settings.config_path):
		return config
	var err := config.load(Settings.config_path)
	if err != OK:
		GsqLogger.error('Error while parsing "%s": %s', [Settings.config_path, err])
	return config

func expand_path(path: String) -> String:
	var res := path
	if path.begins_with("reg://"):
		if not OS.has_feature("windows"):
			return ""
		path = path.trim_prefix("reg://")
		var output := []
		OS.execute("reg", ["query", path.get_base_dir().replace("/", "\\"), "/v", path.get_file()], output)
		#GsqLogger.info("PATH %s: %s" , [path, output])
		if len(output) > 0:
			var stdout: String = output[0]
			var parts := stdout.split("REG_SZ")
			#GsqLogger.info("PARTS %s" , [parts])
			if len(parts) < 2:
				return ""
			var result := ProjectSettings.globalize_path(parts[1].strip_edges())
			#GsqLogger.info("RES %s" , [result])
			return result
		return ""
	res = res.replace("~", OS.get_environment("HOME"))
	res = res.replace("%APPDATA%", OS.get_environment("APPDATA"))
	return res
