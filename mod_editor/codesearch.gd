extends HBoxContainer

@onready var match_case_btn: Button = $MatchCase
@onready var next_btn: Button = $Next
@onready var prev_btn: Button = $Prev
var _match_case_btn_color_disabled: Color

@export var codeedit: CodeEdit
@onready var searchbar: LineEdit = $LineEdit
@onready var label: Label = $Label

var _is_updated := false
var _last_match := Vector2i.MIN
var _last_match_idx := 0
var _num_matches := 0

var _icon_case = Settings.data.pload_image("data:art/ui/textures/MatchCase.svg")
var _icon_prev = Settings.data.pload_image("data:art/ui/textures/MoveUp.svg")
var _icon_next = Settings.data.pload_image("data:art/ui/textures/MoveDown.svg")

func _ready() -> void:
	match_case_btn.icon = ImageTexture.create_from_image(_icon_case)
	prev_btn.icon = ImageTexture.create_from_image(_icon_prev)
	next_btn.icon = ImageTexture.create_from_image(_icon_next)
	codeedit.gui_input.connect(_on_codeedit_gui_input)
	codeedit.text_changed.connect(_on_codeedit_text_changed)
	_match_case_btn_color_disabled = match_case_btn.modulate

func _update_search(text: String) -> void:
	codeedit.queue_redraw()  # update search text highlighting
	_num_matches = codeedit.text.count(text) if match_case_btn.button_pressed else codeedit.text.countn(text)
	if _num_matches > 0:
		label.text = "%s/%s" % [1, _num_matches]
		_last_match_idx = 1
	else:
		label.text = "No results"
	_is_updated = true
	_last_match = Vector2i.MIN

func _on_search_text_changed(new_text: String) -> void:
	_update_search(new_text)

func _on_search_text_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("find_submit"):
		go_to_next_match(true)
		accept_event()

func _on_codeedit_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("find"):
		searchbar.text = codeedit.get_selected_text()
		_update_search(searchbar.text)
		searchbar.grab_focus()
		searchbar.caret_column = len(searchbar.text)
		searchbar.select()
		accept_event()

func _on_codeedit_text_changed() -> void:
	_is_updated = false

func _on_match_case_toggled(toggled_on: bool) -> void:
	match_case_btn.modulate = Color.WHITE if toggled_on else Color.DIM_GRAY
	_update_search(searchbar.text)

func _on_prev_pressed() -> void:
	go_to_next_match(false)
	if codeedit.editable:
		codeedit.grab_focus()

func _on_next_pressed() -> void:
	go_to_next_match(true)
	if codeedit.editable:
		codeedit.grab_focus()

func go_to_next_match(forward: bool = true) -> void:
	if not _is_updated and searchbar.text.strip_edges() != "":
		_update_search(searchbar.text)
	if _num_matches == 0:
		return
	var search_start := Vector2i.ZERO
	if _last_match.x >= 0:
		search_start = _last_match
		if forward:
			search_start.x += len(searchbar.text)
		else:
			search_start.x -= 1
			if search_start.x < 0:
				search_start.y -= 1
				if search_start.y < 0:
					search_start.y = codeedit.get_line_count() - 1
				search_start.x = len(codeedit.get_line(search_start.y))
	var search_flags := 0
	if match_case_btn.button_pressed:
		search_flags |= codeedit.SEARCH_MATCH_CASE
	if not forward:
		search_flags |= codeedit.SEARCH_BACKWARDS
	var next_match := codeedit.search(searchbar.text, search_flags, search_start.y, search_start.x)
	if forward:
		if _last_match.x >= 0 and (
			next_match.y > _last_match.y 
			or (next_match.y == _last_match.y and next_match.x > _last_match.x)
		):
			_last_match_idx += 1
		else:
			_last_match_idx = 1
	else:
		if (
			_last_match.x < 0
			or next_match.y > _last_match.y
			or (next_match.y == _last_match.y and next_match.x > _last_match.x)
		):
			_last_match_idx = _num_matches
		else:
			_last_match_idx -= 1
	codeedit.set_caret_line(next_match.y)
	codeedit.set_caret_column(next_match.x)
	codeedit.center_viewport_to_caret()
	codeedit.select(next_match.y, next_match.x, next_match.y, next_match.x + len(searchbar.text))
	label.text = "%s/%s" % [_last_match_idx, _num_matches]
	_last_match = next_match
