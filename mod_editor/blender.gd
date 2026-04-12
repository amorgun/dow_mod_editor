class_name Blender extends RefCounted

var executable_path := ""
var last_check_error := ""

func _init(executable: String) -> void:
	executable_path = executable

func open_model(model_path: String, mod_dir: String) -> void:
	OS.create_process(executable_path, [
		"--python-expr",
		"import bpy;bpy.ops.import_model.dow_whm_cli(filepath='%s', mod_folder='%s')" % [
			model_path.c_escape(), mod_dir.c_escape(),
		]
	])

func check() -> bool:
	last_check_error = ""
	if not FileAccess.file_exists(executable_path):
		last_check_error = "File does not exist"
		return false
	var output = []
	var exit_code := OS.execute(executable_path, ["-v"], output)
	if exit_code != 0:
		if "blender" not in output[0].to_lower():
			last_check_error = "Selected file is not a Blender executable"
			return false
		last_check_error = "Error: %s" % [output]
		return false
	return true
