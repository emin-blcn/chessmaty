extends Control

signal white_times_up()
signal black_times_up()

var player_color: Enums.ChessColor
var time_per_side: int
var time_increment: int
var white_time_left: int = 0 # in milliseconds
var black_time_left: int = 0 # in milliseconds
var time_left_history: Array[Vector2i] = []

@onready var master_scene: Control = get_tree().current_scene
@onready var hundred_ms_timer: Timer = $hundred_ms_timer
@onready var black_time_message_label: Label = $black_time_message_label
@onready var black_time_label: Label = $black_time_message_label/time_label
@onready var black_ms_label: Label = $black_time_message_label/time_label/ms_label
@onready var white_time_message_label: Label = $white_time_message_label
@onready var white_time_label: Label = $white_time_message_label/time_label
@onready var white_ms_label: Label = $white_time_message_label/time_label/ms_label


func setup(data: Dictionary[String, Variant]) -> void:
	player_color = data.get("player_color")
	time_per_side = data.get("time_per_side")
	time_increment = data.get("time_increment")

	# remove this object if game is not timed mode
	if time_per_side == -60_000:
		queue_free()
		return

	white_time_left = time_per_side
	black_time_left = time_per_side

	# reverse vertical gui elements if player side is black (default order is white)
	if player_color == Enums.ChessColor.BLACK:
		black_time_message_label.position.y = 152.0
		white_time_message_label.position.y = 2.0

	update_white_time_label()
	update_black_time_label()
	show()


func _on_hundred_ms_timer_timeout() -> void:
	match master_scene.get_active_turn():
		Enums.ChessColor.WHITE:
			white_time_left -= 100
			update_white_ms_label()
			if white_time_left % 1000 == 900:
				update_white_time_label()
			if white_time_left == 3000:
				Sound.low_time.play()
		Enums.ChessColor.BLACK:
			black_time_left -= 100
			update_black_ms_label()
			if black_time_left % 1000 == 900:
				update_black_time_label()
			if black_time_left == 3000:
				Sound.low_time.play()

	if white_time_left <= 0:
		white_times_up.emit()
		hundred_ms_timer.stop()
	if black_time_left <= 0:
		black_times_up.emit()
		hundred_ms_timer.stop()


func _on_move_applied(_move_type: Enums.MoveType, _from: String, _to: String) -> void:
	hundred_ms_timer.stop()
	time_left_history.append(Vector2i(white_time_left, black_time_left))

	if time_left_history.size() > 2:
		match master_scene.get_active_turn():
			Enums.ChessColor.WHITE:
				black_time_left += time_increment
				update_black_time_label()
				update_black_ms_label()
			Enums.ChessColor.BLACK:
				white_time_left += time_increment
				update_white_time_label()
				update_white_ms_label()


func _on_promotion_piece_updated(_from: String, _to: String, _role: Enums.PieceRole) -> void:
	_on_move_applied(Enums.MoveType.NORMAL, "", "")
	_on_move_animation_finished()


func _on_put_move_applied(_role: Enums.PieceRole, _to: String) -> void:
	_on_move_applied(Enums.MoveType.NORMAL, "", "")
	_on_move_animation_finished()


func _on_undo_last_move_applied(_double_undo: bool):
	if time_left_history.size() <= 2:
		hundred_ms_timer.stop()

	if time_left_history.is_empty():
		white_time_left = time_per_side
		black_time_left = time_per_side
	else:
		var previous_times: Vector2i = time_left_history.pop_back()
		white_time_left = previous_times.x
		black_time_left = previous_times.y

	update_white_time_label()
	update_white_ms_label()
	update_black_time_label()
	update_black_ms_label()


func _on_move_animation_finished() -> void:
	if master_scene.get_match_finished_state() != Enums.MatchFinishedState.NOT_FINISHED:
		return

	if time_left_history.size() >= 2 and white_time_left > 0 and black_time_left > 0:
		hundred_ms_timer.start()


@warning_ignore_start("integer_division")


func update_white_time_label() -> void:
	var total_seconds: int = white_time_left / 1000
	var hour: int = total_seconds / 3600
	var minute: int = (total_seconds % 3600) / 60
	var second: int = total_seconds % 60

	if time_per_side < 60_000:
		white_time_label.text = "%02d" % [second]
	elif time_per_side < 3_600_000:
		white_time_label.text = "%02d:%02d" % [minute, second]
	else:
		white_time_label.text = "%02d:%02d:%02d" % [hour, minute, second]


func update_white_ms_label() -> void:
	white_ms_label.text = ":%d" % [white_time_left % 1000 / 100]


func update_black_time_label() -> void:
	var total_seconds: int = black_time_left / 1000
	var hour: int = total_seconds / 3600
	var minute: int = (total_seconds % 3600) / 60
	var second: int = total_seconds % 60

	if time_per_side < 60_000:
		black_time_label.text = "%02d" % [second]
	elif time_per_side < 3_600_000:
		black_time_label.text = "%02d:%02d" % [minute, second]
	else:
		black_time_label.text = "%02d:%02d:%02d" % [hour, minute, second]


func update_black_ms_label() -> void:
	black_ms_label.text = ":%d" % [black_time_left % 1000 / 100]


@warning_ignore_restore("integer_division")


func get_white_time_left() -> int:
	return white_time_left


func get_black_time_left() -> int:
	return black_time_left
