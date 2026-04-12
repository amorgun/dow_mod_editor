class_name ModInfo

var mod: ModSet
var loader: ModResourceLoader
var shadow_folder: String
var index: IndexFolder = IndexFolder.new()
var name: String:
	get: return mod.main_mod.name
var _unpacked_sources: Dictionary[String, ModSet.Source] = {}
var _hidden_archives: Dictionary[String, bool] = {}


class IndexFolder:
	var name: String
	var _real_root_path: String = ""
	var real_path: String:
		get:
			if parent == null: return ""
			return parent.real_path.path_join(name) if _real_root_path == "" else _real_root_path
	var folders: Dictionary[String, IndexFolder] = {}
	var files: Dictionary[String, IndexFile] = {}
	var _parent_ref: WeakRef # ModIndexFolder
	var parent: IndexFolder:
		get: return _parent_ref.get_ref() if _parent_ref != null else null
	var source: ModSet.Source
	var is_editable: bool:
		get:
			if source == null: return false 
			return not source.packed and source.mod == source.mod_set.main_mod

	func clear() -> void:
		folders.clear()
		files.clear()

class IndexFile:
	var name: String
	var data: ModSet.FilePath
	var real_path: String:
		get: return data.real_path
	var _parent_ref: WeakRef # ModIndexFolder
	var parent: IndexFolder:
		get: return _parent_ref.get_ref() if _parent_ref != null else null
	var source: ModSet.Source:
		get: return data.source
	var is_editable: bool:
		get: return not source.packed and source.mod == source.mod_set.main_mod
	var _mod_ref: WeakRef
	var mod: ModInfo:
		get: return _mod_ref.get_ref()
	var modified_time: int:
		get: return FileAccess.get_modified_time(data.real_path)
	var shadow_path: String:
		get:
			var parts: PackedStringArray = [name.to_lower()]
			var p := parent
			while p != null:
				parts.append(p.name.to_lower())
				p = p.parent
			parts.remove_at(len(parts) - 1)
			parts.reverse()
			var main_mod := mod.mod.main_mod
			var root := ModSet.try_find_path(main_mod.files_root, main_mod.folder.path_join(mod.shadow_folder))
			return root.path_join("/".join(parts))
	var has_shadow: bool:
		get: return FileAccess.file_exists(shadow_path)
	var shadow_modified_time: int:
		get: return FileAccess.get_modified_time(shadow_path) if has_shadow else 0
	var has_unsaved_shadow: bool:
		get: return shadow_modified_time > modified_time

static func from_mod(mod_: ModSet, shadow_folder_: String) -> ModInfo:
	var result := ModInfo.new()
	result.mod = mod_
	result.loader = ModResourceLoader.create(mod_)
	result.shadow_folder = shadow_folder_
	return result

#func build_index():
	#unpacked_sources = {}
	#for source in mod.sources:
		#if source.packed or source.mod != mod.main_mod:
			#continue
		#unpacked_sources[source.root_folder_name.to_lower()] = source
#
	#index = IndexFolder.new()	
	#index.name = mod.main_mod.name
	#var hidden_archives: Dictionary[String, bool] = {}
	#for s in mod.sources:
		#if not s.packed:
			#continue
		#hidden_archives[s.effective_path.get_file().to_lower()] = true
#
	#var queue := GsqQueue.new()
	#for source in mod.sources:
		#if not source.exists:
			#continue
		##var is_editable := not source.packed and source.mod == main_mod
		#var get_directories := source.get_directories_packed
		#var get_files := source.get_files_packed
		#var start_path := ""
		#if not source.packed:
			#get_directories = source.get_directories_unpacked
			#get_files = source.get_files_unpacked
			#start_path = ModSet.try_find_path(source.effective_path, start_path).substr(len(source.effective_path) + 1)
		#else:
			#mod.load_archive_meta(source)
		#queue.append([index, start_path, mod.find_packed_folder(source.effective_path, "") if source.packed else null])
		#var is_root := true
		#while queue.size():
			#var next = queue.popleft()
			#var next_root: IndexFolder = next[0]
			#var next_path: String = next[1]
			#var next_prefix = next_path + "/" if not next_path.ends_with(":") else next_path
			#var archive_folder: SgaArchive.Folder = next[2]
#
			#for child_name: String in get_directories.call(next_path):
				#var name_lower := child_name.to_lower()
				#var c: IndexFolder = next_root.folders.get(name_lower)
				#if c == null:
					#c = IndexFolder.new()
					#c.name = child_name
					#c._parent_ref = weakref(next_root)
					#c.source = source
					#next_root.folders[name_lower] = c
				#var child_archive_folder: SgaArchive.Folder
				#var child_path := ""
				#if is_root:
					#c._real_root_path = unpacked_sources[child_name].effective_path
					#child_path = child_name + ":"
					#child_archive_folder = archive_folder
				#else:
					#child_path = next_prefix + child_name
					#child_archive_folder = archive_folder.folders[name_lower] if source.packed else null
				#queue.append([c, child_path, child_archive_folder])	
			#for child_name: String in get_files.call(next_path):
				#var name_lower := child_name.to_lower()
				#if name_lower.to_lower() in next_root.files or name_lower in hidden_archives:
					#continue
				#var f := IndexFile.new()
				#f.name = child_name
				#f._parent_ref = weakref(next_root)
				#f._mod_ref = weakref(self)
				#f.data = ModSet.FilePath.new()
				#f.data.source = source
				#var full_path := (next_prefix + f.name).split(":", true, 1)[1]
				#f.data.mod_path = full_path
				#if source.packed:
					#f.data.real_path = source.effective_path
					#f.data._packed_info = archive_folder.files[name_lower]
				#else:
					#f.data.real_path = source.effective_path.path_join(full_path)
				#next_root.files[name_lower] = f
			#is_root = false
	#index_loaded.emit()

func load_sources_data() -> void:
	for source in mod.sources:
		if not source.packed and source.mod == mod.main_mod:
			_unpacked_sources[source.root_folder_name.to_lower()] = source

		if source.packed:
			_hidden_archives[source.effective_path.get_file().to_lower()] = true
		if not source.exists:
			continue
		mod.load_archive_meta(source)

func load_folder(path: ModSet.ModPath, folder_index: IndexFolder) -> void:
	for source in mod.sources:
		if not source.exists:
			continue
		var get_directories := source.get_directories_packed
		var get_files := source.get_files_packed
		if not source.packed:
			get_directories = source.get_directories_unpacked
			get_files = source.get_files_unpacked
		for child_name: String in get_directories.call(path):
			var name_lower := child_name.to_lower()
			var c: IndexFolder = folder_index.folders.get(name_lower)
			if c == null:
				c = IndexFolder.new()
				c.name = child_name
				c._parent_ref = weakref(folder_index)
				c.source = source
				folder_index.folders[name_lower] = c
				if path == ModSet.ModPath.ROOT:
					c._real_root_path = _unpacked_sources[child_name].effective_path
		for child_name: String in get_files.call(path):
			var name_lower := child_name.to_lower()
			if name_lower in folder_index.files or name_lower in _hidden_archives:
				continue
			var f := IndexFile.new()
			f.name = child_name
			f._parent_ref = weakref(folder_index)
			f._mod_ref = weakref(self)
			f.data = ModSet.FilePath.new()
			f.data.source = source
			var full_path: ModSet.ModPath = ModSet.ModPath.from_parts(name_lower) if path == ModSet.ModPath.ROOT else path.join(name_lower)
			f.data.mod_path = full_path
			if source.packed:
				f.data.real_path = source.effective_path
				#f.data._packed_info = archive_folder.files[name_lower]
			else:
				f.data.real_path = ModSet.try_find_path(source.effective_path, full_path.path)
			folder_index.files[name_lower] = f


var DUMMY_ROOT := IndexFolder.new()


func create_config_file_info() -> IndexFile:
	var path := mod.main_mod.config_path
	var file := ModSet.FilePath.new()
	file.real_path = path
	file.mod_path = ModSet.ModPath.ROOT
	file.source = ModSet.Source.new()
	file.source.packed = false
	file.source.effective_path = path
	var result := IndexFile.new()
	result.name = path.get_file()
	result.data = file
	result._parent_ref = weakref(DUMMY_ROOT)
	result._mod_ref = weakref(self)
	return result

func unpack_file(file: IndexFile) -> void:
	var parent := file.parent
	var node := parent
	var path_parts: Array[IndexFolder] = []
	while node != null:
		path_parts.append(node)
		node = node.parent
	var source := _unpacked_sources[path_parts[-2].name.to_lower()]
	var folder := DirAccess.open(mod.main_mod.config_path.get_base_dir())
	for part in source.effective_relative_path.simplify_path().split("/"):
		var lookup := ModSet.find_child_case_insensitive(folder, part)
		var child: String = lookup[0]
		# var is_folder: bool = lookup[1]
		# TODO error
		if child == "":
			folder.make_dir(part)
			child = part
		folder.change_dir(child)
	path_parts.pop_back()  # mod
	var root: IndexFolder = path_parts.pop_back()
	root.source = source
	path_parts.reverse()
	for item in path_parts:
		var lookup := ModSet.find_child_case_insensitive(folder, item.name)
		var child: String = lookup[0]
		if child == "":
			folder.make_dir(item.name)
			child = item.name
		item.source = source
		folder.change_dir(child)
	var tgd_file := FileAccess.open(folder.get_current_dir().path_join(file.name), FileAccess.WRITE)
	tgd_file.store_buffer(file.data.read_bytes())
	file.data.source = source
	file.data.real_path = tgd_file.get_path_absolute()
