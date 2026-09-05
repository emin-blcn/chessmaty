extends Control

signal white_times_up()
signal black_times_up()

@onready var master_scene: Control = get_tree().current_scene
@onready var second_timer: Timer = $second_timer
@onready var black_time_message_label: Label = $black_time_message_label
@onready var black_time_label: Label = $black_time_message_label/time_label
@onready var white_time_message_label: Label = $white_time_message_label
@onready var white_time_label: Label = $white_time_message_label/time_label

var player_color: Enums.ChessColor
var time_per_side: int
var time_increment: int
var white_time_left: int = 0
var black_time_left: int = 0
var time_left_history: Array[Vector2i] = []
var active_turn: Enums.ChessColor = Enums.ChessColor.WHITE


func config(new_config_data: Dictionary[String, Variant]):
	player_color = new_config_data["player_color"]
	time_per_side = new_config_data["time_per_side"]
	time_increment = new_config_data["time_increment"]
	
	# remove this object if game is not timed mode
	if time_per_side == -60_000:
		queue_free()
	else:
		white_time_left = time_per_side
		black_time_left = time_per_side
		
		# reverse gui elements if player side is black (default gui order is white)
		if player_color == Enums.ChessColor.BLACK:
			black_time_message_label.position.y = 152.0
			white_time_message_label.position.y = 2.0
		
		update_white_time_gui()
		update_black_time_gui()
		show()


func _on_second_timer_timeout() -> void:
	match active_turn:
		Enums.ChessColor.WHITE:
			white_time_left -= 1000
			update_white_time_gui()
		Enums.ChessColor.BLACK:
			black_time_left -= 1000
			update_black_time_gui()
	
	if white_time_left <= 0:
		white_times_up.emit()
		return
	if black_time_left <= 0:
		black_times_up.emit()
		return
	
	second_timer.start()


func _on_move_animation_started(move_type: Enums.MoveType, _from: String, _to: String):
	second_timer.stop()
	
	if move_type == Enums.MoveType.PROMOTION:
		return
	elif move_type == Enums.MoveType.UNDO:
		if time_left_history.is_empty():
			white_time_left = time_per_side
			black_time_left = time_per_side
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
					black_time_left += time_increment
					update_black_time_gui()
				Enums.ChessColor.BLACK:
					white_time_left += time_increment
					update_white_time_gui()


func _on_move_animation_finished(_move_type: Enums.MoveType):
	if master_scene.get_match_finished_state() != Enums.MatchFinishedState.NOT_FINISHED:
		return
	
	if time_left_history.size() >= 2 and white_time_left > 0 and black_time_left > 0:
		second_timer.start()


func update_white_time_gui():
	@warning_ignore_start("integer_division")
	var total_seconds: int = white_time_left / 1000
	var hour: int = total_seconds / 3600
	var minute: int = (total_seconds % 3600) / 60
	var second: int = total_seconds % 60
	@warning_ignore_restore("integer_division")
	
	if time_per_side < 60_000:
		white_time_label.text = "%02d" % [second]
	elif time_per_side < 3_600_000:
		white_time_label.text = "%02d:%02d" % [minute, second]
	else:
		white_time_label.text = "%02d:%02d:%02d" % [hour, minute, second]


func update_black_time_gui():
	@warning_ignore_start("integer_division")
	var total_seconds: int = black_time_left / 1000
	var hour: int = total_seconds / 3600
	var minute: int = (total_seconds % 3600) / 60
	var second: int = total_seconds % 60
	@warning_ignore_restore("integer_division")
	
	if time_per_side < 60_000:
		black_time_label.text = "%02d" % [second]
	elif time_per_side < 3_600_000:
		black_time_label.text = "%02d:%02d" % [minute, second]
	else:
		black_time_label.text = "%02d:%02d:%02d" % [hour, minute, second]


func get_white_time_left() -> int:
	return white_time_left


func get_black_time_left() -> int:
	return black_time_left
