class_name ChunkyPreviewWindow extends HSplitContainer

@onready var chunk_tree: Tree = $Tree
@onready var typeid_edit: LineEdit = $Preview/Header/ShortValues/TypeID/LineEdit
@onready var version_edit: LineEdit = $Preview/Header/ShortValues/Version/LineEdit
@onready var size_edit: LineEdit = $Preview/Header/ShortValues/Size/LineEdit
@onready var name_edit: LineEdit = $Preview/Header/Name/LineEdit
@onready var hex_edit: TextEdit = $Preview/Hex

const LINE_SIZE := 16
var data: PackedByteArray

var _icon_data := Settings.data.pload_image("data:art/ui/textures/File.svg")
var _icon_folder := Settings.data.pload_image("data:art/ui/textures/Folder.svg")

func clear():
	chunk_tree.clear()
	typeid_edit.text = ""
	version_edit.text = ""
	size_edit.text = ""
	name_edit.text = ""
	hex_edit.text = ""

func view_item(node: TreeItem) -> void:
	var index: ChunkReader.ChunkIndex = node.get_meta("index")
	typeid_edit.text = index.typeid
	version_edit.text = str(index.version)
	size_edit.text = str(index.size)
	name_edit.text = index.name
	if index.is_folder():
		hex_edit.text = ""
		return
	var text_lines: PackedStringArray = []
	var pos := index.data_start
	while pos < index.data_end:
		var end := mini(index.data_end, pos + LINE_SIZE)
		var hex_parts: PackedStringArray = []
		var char_parts: PackedStringArray = []
		for i in LINE_SIZE:
			var h := "   "
			var c := ""
			if pos + i < index.data_end:
				var b := data[pos + i]
				h = "%02X " % b
				c = "."
				if (
					(ord("a") <= b and b <= ord("z"))
					or (ord("A") <= b and b <= ord("Z"))
					or (ord("0") <= b and b <= ord("9"))
				):
					c = String.chr(b)
			hex_parts.append(h)
			
			char_parts.append(c)
			
		text_lines.append_array(hex_parts)
		text_lines.append("      ")
		text_lines.append_array(char_parts)
		text_lines.append("\n")
		pos = end
	hex_edit.text = "".join(text_lines)

func set_data(new_data: PackedByteArray) -> TreeItem:
	data = new_data
	clear()
	var index_root := ChunkReader.build_chunk_index(data)
	if index_root == null: return null
	var root := chunk_tree.create_item()
	var queue := GsqQueue.new([[index_root, root]])
	while queue.size():
		var top = queue.popleft()
		var index: ChunkReader.ChunkIndex = top[0]
		var node: TreeItem = top[1]
		node.set_meta("index", index)
		node.set_text(0, index.typeid.substr(4))
		if index.is_folder():
			for c in index.children:
				var new_node := chunk_tree.create_item(node)
				queue.append([c, new_node])
			node.set_icon(0, ImageTexture.create_from_image(_icon_folder))
		else:
			node.set_icon(0, ImageTexture.create_from_image(_icon_data))
	return root

func _on_tree_item_activated() -> void:
	var selected := chunk_tree.get_selected()
	if selected.get_meta("is_folder", false):
		selected.collapsed = not selected.collapsed
	else:
		view_item(selected)
