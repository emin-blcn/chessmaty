extends Control

signal white_times_up()
signal black_times_up()

@onready var master_scene: Control = get_tree().current_scene
@onready var top_time_message_label: Label = $top_time_message_label
@onready var top_time_label: Label = $top_time_message_label/time_label
@onready var top_ms_label: Label = $top_time_message_label/time_label/ms_label

@onready var bottom_time_message_label: Label = $bottom_time_message_label
@onready var bottom_time_label: Label = $bottom_time_message_label/time_label
@onready var bottom_ms_label: Label = $bottom_time_message_label/time_label/ms_label

var config_data: Dictionary[String, Variant] = {}
var white_time_left: int = 0
var black_time_left: int = 0
var time_left_history: Array[Vector2i] = []
var active_turn: Enums.ChessColor = Enums.ChessColor.WHITE
var time_is_ticking: bool = false


func config(new_config_data: Dictionary):
	config_data["player_color"] = new_config_data["player_color"]
	config_data["time_per_side"] = new_config_data["time_per_side"]
	config_data["time_increment"] = new_config_data["time_increment"]
	
	# remove this object if game is not timed mode
	if config_data["time_per_side"] == -60_000:
		queue_free()
	else:
		white_time_left = config_data["time_per_side"]
		black_time_left = config_data["time_per_side"]
		
		if config_data["player_color"] == Enums.ChessColor.BLACK:
			top_time_message_label.text = "White time left:"
			top_time_message_label.add_theme_color_override("font_color", Color("a6bac4ff"))
			bottom_time_message_label.text = "Black time left:"
			bottom_time_message_label.add_theme_color_override("font_color", Color("70334cff"))
		update_white_time_gui()
		update_black_time_gui()
		show()


var last_time: int = Time.get_ticks_msec()
var last_white_time: int
var last_black_time: int


func _physics_process(_delta: float) -> void:
	# update hour-min-sec label per second and update millisecond label at 60 times at second
	if time_is_ticking:
		if white_time_left <= 0:
			time_is_ticking = false
			white_times_up.emit()
		if black_time_left <= 0:
			time_is_ticking = false
			black_times_up.emit()
		
		match active_turn:
			Enums.ChessColor.WHITE:
				white_time_left = white_time_left - (Time.get_ticks_msec() - last_time)
				update_white_ms_time_gui()
				if white_time_left % 1000 > last_white_time % 1000:
					update_white_time_gui()
				last_white_time = white_time_left
			Enums.ChessColor.BLACK:
				black_time_left = black_time_left - (Time.get_ticks_msec() - last_time)
				update_black_ms_time_gui()
				if black_time_left % 1000 > last_black_time % 1000:
					update_black_time_gui()
				last_black_time = black_time_left
	
	last_time = Time.get_ticks_msec()


func _on_move_animation_started(move_type: Enums.MoveType, _from: String, _to: String):
	time_is_ticking = false
	
	if move_type == Enums.MoveType.UNDO:
		if time_left_history.is_empty():
			white_time_left = config_data["time_per_side"]
			black_time_left = config_data["time_per_side"]
		else:
			var previous_times: Vector2i = time_left_history.pop_back()
			white_time_left = previous_times.x
			black_time_left = previous_times.y
		update_white_time_gui()
		update_black_time_gui()
	else:
		time_left_history.append(Vector2i(white_time_left, black_time_left))
		active_turn = master_scene.get_turn()
		
		if time_left_history.size() > 2:
			match active_turn:
				Enums.ChessColor.WHITE:
					black_time_left += config_data["time_increment"]
					update_black_time_gui()
				Enums.ChessColor.BLACK:
					white_time_left += config_data["time_increment"]
					update_white_time_gui()


func _on_move_animation_finished(_move_type: Enums.MoveType):
	if master_scene.get_match_finished_state() != Enums.MatchFinishedState.NOT_FINISHED:
		return
	
	if time_left_history.size() >= 2 and white_time_left > 0 and black_time_left > 0:
		time_is_ticking = true


func update_white_time_gui():
	var white_time_label: Label = bottom_time_label if config_data["player_color"] == Enums.ChessColor.WHITE else top_time_label
	@warning_ignore_start("integer_division")
	var total_seconds: int = white_time_left / 1000
	var hour: int = total_seconds / 3600
	var minute: int = (total_seconds % 3600) / 60
	var second: int = total_seconds % 60
	@warning_ignore_restore("integer_division")
	
	if white_time_left >= 3_600_000:
		white_time_label.text = "%02d:%02d:%02d" % [hour, minute, second]
	elif white_time_left >= 60_000:
		white_time_label.text = "%02d:%02d" % [minute, second]
	else:
		white_time_label.text = "%02d" % [second]


func update_black_time_gui():
	var black_time_label: Label = bottom_time_label if config_data["player_color"] == Enums.ChessColor.BLACK else top_time_label
	@warning_ignore_start("integer_division")
	var total_seconds: int = black_time_left / 1000
	var hour: int = total_seconds / 3600
	var minute: int = (total_seconds % 3600) / 60
	var second: int = total_seconds % 60
	@warning_ignore_restore("integer_division")
	
	if black_time_left >= 3_600_000:
		black_time_label.text = "%02d:%02d:%02d" % [hour, minute, second]
	elif black_time_left >= 60_000:
		black_time_label.text = "%02d:%02d" % [minute, second]
	else:
		black_time_label.text = "%02d" % [second]


func update_white_ms_time_gui():
	var white_ms_label: Label = bottom_ms_label if config_data["player_color"] == Enums.ChessColor.WHITE else top_ms_label
	@warning_ignore("integer_division")
	if white_time_left <= 0:
		white_ms_label.text = ":0"
	else:
		white_ms_label.text = ":" + str(white_time_left % 1000)[0]


func update_black_ms_time_gui():
	var black_ms_label: Label = bottom_ms_label if config_data["player_color"] == Enums.ChessColor.BLACK else top_ms_label
	@warning_ignore("integer_division")
	if black_time_left <= 0:
		black_ms_label.text = ":0"
	else:
		black_ms_label.text = ":" + str(black_time_left % 1000)[0]


func get_white_time_left() -> int:
	return white_time_left


func get_black_time_left() -> int:
	return black_time_left
