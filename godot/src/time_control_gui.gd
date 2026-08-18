extends Control

signal white_times_up()
signal black_times_up()

@onready var master_scene: Control = get_tree().current_scene
@onready var top_time_message_label: Label = $top_time_message_label
@onready var top_time_left_label: Label = $top_time_message_label/top_time_left_label
@onready var bottom_time_message_label: Label = $bottom_time_message_label
@onready var bottom_time_left_label: Label = $bottom_time_message_label/bottom_time_left_label
@onready var timer: Timer = $Timer

var config_data: Dictionary
var white_time_left_second: int = 0
var black_time_left_second: int = 0
var time_left_seconds_in_moves: Array[Vector2i]


func config(new_config_data: Dictionary):
	config_data = new_config_data
	
	if is_equal_approx(config_data["minute_per_side"], 999.0):
		queue_free()
	else:
		white_time_left_second = int(config_data["minute_per_side"] * 60)
		black_time_left_second = int(config_data["minute_per_side"] * 60)
		
		if config_data["player_color"] == Enums.ChessColor.BLACK:
			top_time_message_label.text = "White time left:"
			top_time_message_label.add_theme_color_override("font_color", Color("a6bac4ff"))
			bottom_time_message_label.text = "Black time left:"
			bottom_time_message_label.add_theme_color_override("font_color", Color("70334cff"))
		update_white_time_gui()
		update_black_time_gui()
		show()


func _on_timer_timeout() -> void:
	match master_scene.get_turn():
		Enums.ChessColor.WHITE:
			white_time_left_second -= 1
			update_white_time_gui()
		Enums.ChessColor.BLACK:
			black_time_left_second -= 1
			update_black_time_gui()
	
	if white_time_left_second <= 0:
		timer.stop()
		white_times_up.emit()
	if black_time_left_second <= 0:
		timer.stop()
		black_times_up.emit()


func _on_move_animation_started(move_type: Enums.MoveType, _from: String, _to: String):
	timer.stop()
	if move_type == Enums.MoveType.UNDO:
		if time_left_seconds_in_moves.is_empty():
			var full_seconds = config_data["minute_per_side"] * 60
			white_time_left_second = full_seconds
			black_time_left_second = full_seconds
		else:
			var previous_times: Vector2i = time_left_seconds_in_moves.pop_back()
			white_time_left_second = previous_times.x
			black_time_left_second = previous_times.y
		update_white_time_gui()
		update_black_time_gui()
	else:
		time_left_seconds_in_moves.append(Vector2i(white_time_left_second, black_time_left_second))
		
		if time_left_seconds_in_moves.size() >= 2:
			match master_scene.get_turn():
				Enums.ChessColor.WHITE:
					white_time_left_second += config_data["increment_second"]
					update_white_time_gui()
				Enums.ChessColor.BLACK:
					black_time_left_second += config_data["increment_second"]
					update_black_time_gui()


func _on_move_animation_finished(_move_type: Enums.MoveType):
	if master_scene.get_match_finished_state() == Enums.MatchFinishedState.NOT_FINISHED:
		return
	if time_left_seconds_in_moves.size() >= 2 and white_time_left_second > 0 and black_time_left_second > 0:
		timer.start()


func update_white_time_gui():
	var label_node: Label = bottom_time_left_label if config_data["player_color"] == Enums.ChessColor.WHITE else top_time_left_label
	@warning_ignore("integer_division")
	var hour = white_time_left_second / 3600
	@warning_ignore("integer_division")
	var minute = (white_time_left_second % 3600) / 60
	var second = white_time_left_second % 60
	
	if config_data["minute_per_side"] >= 60:
		label_node.text = "%02d:%02d:%02d" % [hour, minute, second]
	else:
		label_node.text = "%02d:%02d" % [minute, second]


func update_black_time_gui():
	var label_node: Label = bottom_time_left_label if config_data["player_color"] == Enums.ChessColor.BLACK else top_time_left_label
	@warning_ignore("integer_division")
	var hour = black_time_left_second / 3600
	@warning_ignore("integer_division")
	var minute = (black_time_left_second % 3600) / 60
	var second = black_time_left_second % 60
	
	if config_data["minute_per_side"] >= 60:
		label_node.text = "%02d:%02d:%02d" % [hour, minute, second]
	else:
		label_node.text = "%02d:%02d" % [minute, second]


func get_white_time_left_second() -> int:
	return white_time_left_second


func get_black_time_left_second() -> int:
	return black_time_left_second
