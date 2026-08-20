class_name ApiDispatcher extends Node

const DEFAULT_TCP_PORT := 8765

var _tcp_api: TcpApi = null

func _process(_delta: float) -> void:
	if Settings.config_path == "":
		return
	set_process(false)
	if Settings.cli_flag_value("--cli-api") != "":
		add_child(CliApi.new())
		GsqLogger.info("CLI API (stdio) started")
	var config := Settings.get_config()
	var tcp_flag := Settings.cli_flag_value("--cli-api-tcp")
	if tcp_flag != "" or config.get_value("tcp_api", "enabled", false) or Settings.cli_flag_value("--headless-api") != "":
		var port: int = tcp_flag.to_int() if tcp_flag.is_valid_int() else config.get_value("tcp_api", "port", DEFAULT_TCP_PORT)
		start_tcp_api(port)

func start_tcp_api(port: int) -> bool:
	if _tcp_api != null:
		if _tcp_api.port == port:
			return true
		stop_tcp_api()
	_tcp_api = TcpApi.new()
	add_child(_tcp_api)
	if _tcp_api.start_server(port) != OK:
		_tcp_api.queue_free()
		_tcp_api = null
		GsqLogger.error("Cannot start TCP API on port %d" % port)
		return false
	GsqLogger.info("Running TCP Api on 127.0.0.1:%d" % port)
	return true

func stop_tcp_api() -> void:
	if _tcp_api == null:
		return
	_tcp_api.stop_server()
	_tcp_api.queue_free()
	_tcp_api = null
	GsqLogger.info("TCP API stopped")

func is_tcp_api_running() -> bool:
	return _tcp_api != null

var port: int:
	get: return _tcp_api.port if _tcp_api != null else 0

## Optional gitignored debug hooks (mod_editor/api/debug_api.gd); absent in
## clean checkouts and exports.
var _debug: RefCounted = load("res://mod_editor/api/debug_api.gd").new() if ResourceLoader.exists("res://mod_editor/api/debug_api.gd") else null

func handle_message(msg: Dictionary) -> Dictionary:
	var id: Variant = msg.get("id")
	var method := str(msg.get("method", ""))
	var params: Variant = msg.get("params", {})
	if params is not Dictionary:
		return _error_response(id, "bad_request", "params must be an object")
	if _debug != null:
		var handled: Variant = _debug.handle(self, id, method, params)
		if handled != null:
			return handled
	match method:
		"get_open_mods":
			return _result_response(id, CoreApi.Result.success(Core.get_open_mods()))
		"get_mod_status":
			var found := _find_mod(params)
			if not found.ok:
				return _error_response(id, found.code, found.error)
			return _result_response(id, CoreApi.Result.success({"status": _status_name(found.data)}))
		"open_mod":
			var path := str(params.get("path", ""))
			if path == "":
				return _error_response(id, "bad_request", "path is required")
			return _result_response(id, CoreApi.Result.success({"status": _status_name(Core.open_mod(path))}))
		"folder_content":
			var found := _find_folder(params)
			if not found.ok:
				return _error_response(id, found.code, found.error)
			return _result_response(id, Core.folder_content(found.data))
		"get_text":
			var found := _find_file(params)
			if not found.ok:
				return _error_response(id, found.code, found.error)
			return _result_response(id, Core.get_text(found.data))
		"get_meta":
			var found := _find_file(params)
			if not found.ok:
				return _error_response(id, found.code, found.error)
			return _result_response(id, Core.get_file_meta(found.data))
		"execute":
			var found := _find_file(params)
			if not found.ok:
				return _error_response(id, found.code, found.error)
			return _result_response(id, await Core.execute_lua(found.data))
		"set_text":
			if not params.has("content"):
				return _error_response(id, "bad_request", "content is required")
			var mod_path := ModSet.ModPath.from_path(str(params.get("path", "")))
			if mod_path.is_root() or mod_path.path == "":
				return _error_response(id, "bad_request", "File path expected")
			var found_mod := _find_mod(params)
			if not found_mod.ok:
				return _error_response(id, found_mod.code, found_mod.error)
			var file := Core.find_file(found_mod.data, str(params.get("path", "")))
			if file.ok:
				return _result_response(id, Core.set_text(file.data, str(params["content"])))
			var folder := Core.find_folder(found_mod.data, _parent_path(mod_path))
			if not folder.ok:
				return _error_response(id, folder.code, folder.error)
			return _result_response(id, Core.set_text(folder.data.create_child(mod_path.path.get_file()), str(params["content"]), true))
		"save_image":
			var dest := str(params.get("dest", ""))
			if dest == "":
				return _error_response(id, "bad_request", "dest is required")
			var found := _find_file(params)
			if not found.ok:
				return _error_response(id, found.code, found.error)
			var size := Vector2i(int(params.get("width", 0)), int(params.get("height", 0)))
			var zoom := float(params.get("zoom", 0.0))
			return _result_response(id, await Core.save_image_async(found.data, dest, size, zoom))
		"extract_file":
			var real_path := str(params.get("real_path", ""))
			if real_path == "":
				return _error_response(id, "bad_request", "real_path is required")
			var found := _find_file(params)
			if not found.ok:
				return _error_response(id, found.code, found.error)
			return _result_response(id, Core.extract_file(found.data, real_path))
		"copy_file":
			var found_from := _find_file(params, "mod", "path_from")
			if not found_from.ok:
				return _error_response(id, found_from.code, found_from.error)
			var found_mod_to := _find_mod(params, "mod_to")
			if not found_mod_to.ok:
				return _error_response(id, found_mod_to.code, found_mod_to.error)
			var path_to := ModSet.ModPath.from_path(str(params.get("path_to", "")))
			if path_to.is_root() or path_to.path == "":
				return _error_response(id, "bad_request", "File path expected")
			var folder_to := Core.find_folder(found_mod_to.data, _parent_path(path_to))
			if not folder_to.ok:
				return _error_response(id, folder_to.code, folder_to.error)
			return _result_response(id, Core.copy_file(found_from.data, folder_to.data, path_to.path.get_file()))
	return _error_response(id, "bad_request", "Unknown method: %s" % method)

static func _error_response(id: Variant, code: String, message: String) -> Dictionary:
	return {"jsonrpc": "2.0", "id": id, "error": {"code": code, "message": message}}

static func _result_response(id: Variant, result: CoreApi.Result) -> Dictionary:
	if result.ok:
		return {"jsonrpc": "2.0", "id": id, "result": result.data}
	return _error_response(id, result.code, result.error)

static func _status_name(mod_info: ModInfo) -> String:
	return CoreApi.ModStatus.keys()[Core.get_mod_status(mod_info)].to_lower()

static func _parent_path(path: ModSet.ModPath) -> String:
	return ModSet.ModPath.from_parts(path.root_folder, path.path.get_base_dir()).full_path

func _find_mod(params: Dictionary, key := "mod") -> CoreApi.Result:
	var module_path := str(params.get(key, ""))
	if module_path == "":
		return CoreApi.Result.failure("bad_request", "%s is required" % key)
	var mod_info := Core.get_mod(module_path)
	if mod_info == null:
		return CoreApi.Result.failure("not_found", "Mod is not open: %s" % module_path)
	return CoreApi.Result.success(mod_info)

func _find_file(params: Dictionary, mod_key := "mod", path_key := "path") -> CoreApi.Result:
	var found := _find_mod(params, mod_key)
	if not found.ok:
		return found
	return Core.find_file(found.data, str(params.get(path_key, "")))

func _find_folder(params: Dictionary, path := "") -> CoreApi.Result:
	var found := _find_mod(params)
	if not found.ok:
		return found
	if path == "":
		path = str(params.get("path", ""))
	return Core.find_folder(found.data, path)
