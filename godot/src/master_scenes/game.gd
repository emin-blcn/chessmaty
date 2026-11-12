extends Control

const MOVE_MSG: String = "CHESSMATY_MOVE"
const UNDO_REQUEST_MSG: String = "CHESSMATY_UNDO_REQUEST"
const UNDO_RESPONSE_MSG: String = "CHESSMATY_UNDO_RESPONSE"

var player_color: Enums.ChessColor
var game_mode: Enums.GameMode
var connection_type: Enums.ConnectionType
var local_opponent: Enums.LocalOpponent
var is_timed_game: bool
var chess_logic: ChessLogic = ChessLogic.new()
var listen_lan_opponent_thread: Thread
var lan_stream # host or peer (same named functions)
var active_turn: Enums.ChessColor = Enums.ChessColor.WHITE
var is_game_started: bool = false
var is_local_ai_thinking: bool = false
var is_undo_requested: bool = false
var promotion_move_data: Dictionary[String, Variant] = {"from": "", "to": "", "role": Enums.PieceRole.EMPTY}

@onready var game_content_node: Control = $game_content
@onready var board_node: Control = $game_content/board
@onready var hud_elements_node: Control = $game_content/hud_elements
@onready var move_history_table_node: VBoxContainer = $game_content/hud_elements/move_history_table
@onready var time_node: Control = $game_content/hud_elements/time
@onready var three_check_node: Control = $game_content/hud_elements/three_check
@onready var crazy_house_node: Control = $game_content/hud_elements/crazy_house
@onready var promotion_selection_node: TextureRect = $game_content/hud_elements/promotion_selection
@onready var received_undo_request_node: TextureRect = $game_content/hud_elements/received_undo_request
@onready var opponent_left_node: TextureRect = $game_content/hud_elements/opponent_left
@onready var match_finished_node: Control = $game_content/hud_elements/match_finished
@onready var game_setup_node: TabContainer = $game_setup


func _ready() -> void:
	game_setup_node.get_node("game_setup_local").setup_finished.connect(_on_setup_finished)
	game_setup_node.get_node("game_setup_lan").setup_finished.connect(_on_setup_finished)

	chess_logic.move_applied.connect(_on_move_applied)
	chess_logic.move_applied.connect(board_node._on_move_applied)
	chess_logic.move_applied.connect(move_history_table_node._on_move_applied)
	chess_logic.move_applied.connect(time_node._on_move_applied)
	chess_logic.move_applied.connect(crazy_house_node._on_move_applied)

	chess_logic.promotion_piece_updated.connect(_on_promotion_piece_updated)
	chess_logic.promotion_piece_updated.connect(board_node._on_promotion_piece_updated)
	chess_logic.promotion_piece_updated.connect(move_history_table_node._on_promotion_piece_updated)
	chess_logic.promotion_piece_updated.connect(time_node._on_promotion_piece_updated)
	chess_logic.promotion_piece_updated.connect(crazy_house_node._on_promotion_piece_updated)

	chess_logic.promotion_move_played_by_ai.connect(_on_promotion_move_played_by_ai)

	chess_logic.put_move_applied.connect(_on_put_move_applied)
	chess_logic.put_move_applied.connect(board_node._on_put_move_applied)
	chess_logic.put_move_applied.connect(move_history_table_node._on_put_move_applied)
	chess_logic.put_move_applied.connect(time_node._on_put_move_applied)
	chess_logic.put_move_applied.connect(crazy_house_node._on_put_move_applied)

	chess_logic.undo_last_move_applied.connect(_on_undo_last_move_applied)
	chess_logic.undo_last_move_applied.connect(board_node._on_undo_last_move_applied)
	chess_logic.undo_last_move_applied.connect(move_history_table_node._on_undo_last_move_applied)
	chess_logic.undo_last_move_applied.connect(time_node._on_undo_last_move_applied)
	chess_logic.undo_last_move_applied.connect(three_check_node._on_undo_last_move_applied)
	chess_logic.undo_last_move_applied.connect(crazy_house_node._on_undo_last_move_applied)

	board_node.move_animation_finished.connect(_on_move_animation_finished)
	board_node.move_animation_finished.connect(time_node._on_move_animation_finished)
	board_node.move_animation_finished.connect(three_check_node._on_move_animation_finished)
	board_node.promotion_selection_required.connect(promotion_selection_node.show_promotion_selection)

	time_node.white_times_up.connect(_on_white_times_up)
	time_node.black_times_up.connect(_on_black_times_up)

	crazy_house_node.put_piece_selected.connect(board_node._on_put_piece_selected)
	crazy_house_node.put_piece_unselected.connect(board_node._on_put_piece_unselected)


func _on_setup_finished(data: Dictionary[String, Variant]) -> void:
	player_color = data.get("player_color")
	game_mode = data.get("game_mode")
	connection_type = data.get("connection_type")
	if connection_type == Enums.ConnectionType.LOCAL:
		local_opponent = data.get("local_opponent")
	is_timed_game = data.get("time_per_side") != -60_000

	chess_logic.setup(data)
	board_node.setup(data)
	hud_elements_node.setup(data)
	promotion_selection_node.setup(data)
	time_node.setup(data)
	three_check_node.setup(data)
	crazy_house_node.setup(data)

	match connection_type:
		Enums.ConnectionType.LOCAL:
			opponent_left_node.queue_free()
			if local_opponent == Enums.LocalOpponent.AI and player_color == Enums.ChessColor.BLACK:
				play_ai_move()
		Enums.ConnectionType.LAN:
			listen_lan_opponent_thread = Thread.new()
			listen_lan_opponent_thread.start(wait_for_lan_opponent_msg)

	game_content_node.show()
	game_setup_node.queue_free()
	is_game_started = true


func init_stream(new_stream) -> void:
	lan_stream = new_stream


func wait_for_lan_opponent_msg() -> void:
	while true:
		var received_text: String = lan_stream.wait_for_opponent_msg()
		if received_text.is_empty():
			call_deferred("_on_received_leave_msg_from_lan_opponent")
			break

		var received_json_data: Dictionary = JSON.parse_string(received_text)
		var received_msg: String = received_json_data.get("msg")
		var received_params: Dictionary = received_json_data.get("params")

		match received_msg:
			MOVE_MSG:
				var move_type: Enums.MoveType = int(received_params.get("move_type")) as Enums.MoveType
				var from: String = received_params.get("from")
				var to: String = received_params.get("to")
				var promotion_or_put_role: Enums.PieceRole = int(received_params.get("promotion_or_put_role")) as Enums.PieceRole
				call_deferred("_on_received_move_msg_from_lan_opponent", move_type, from, to, promotion_or_put_role)
			UNDO_REQUEST_MSG:
				call_deferred("_on_received_undo_request_msg_from_lan_opponent")
			UNDO_RESPONSE_MSG:
				var response: bool = received_params.get("response")
				call_deferred("_on_received_undo_response_msg_from_lan_opponent", response)


func _on_received_leave_msg_from_lan_opponent() -> void:
	if !match_finished_node.visible:
		opponent_left_node.show()


func _on_received_undo_request_msg_from_lan_opponent() -> void:
	if !match_finished_node.visible:
		received_undo_request_node.show()


func accept_undo_request() -> void:
	lan_stream.send_undo_response_msg_to_opponent(true)

	if player_color == get_active_turn() or get_position_history_count() == 1:
		chess_logic.undo_last_move(false)
	else:
		chess_logic.undo_last_move(true)

	received_undo_request_node.hide()


func reject_undo_request() -> void:
	lan_stream.send_undo_response_msg_to_opponent(false)
	received_undo_request_node.hide()


func _on_received_undo_response_msg_from_lan_opponent(undo_request_accepted: bool) -> void:
	if undo_request_accepted:
		if player_color != get_active_turn() or get_position_history_count() == 1:
			chess_logic.undo_last_move(false)
		else:
			chess_logic.undo_last_move(true)

	hud_elements_node._on_responded_undo_request(undo_request_accepted)


func _on_received_move_msg_from_lan_opponent(move_type: Enums.MoveType, from: String, to: String, promotion_or_put_role: Enums.PieceRole) -> void:
	match move_type:
		Enums.MoveType.NORMAL:
			apply_normal_move(from, to)
		Enums.MoveType.EN_PASSANT:
			apply_en_passant_move(from, to)
		Enums.MoveType.CASTLING:
			apply_castling_move(from, to)
		Enums.MoveType.PROMOTION:
			update_promotion_move_squares_data(from, to)
			update_promotion_move_role_data(promotion_or_put_role)
			board_node.apply_promotion_move_and_play_animation(from, to)
			apply_promotion_move()
		Enums.MoveType.PUT:
			apply_put_move(promotion_or_put_role, to)


# Note: when chess_logic.apply_*_move() functions are called, switches the turn.
# some tasks must be execute before switching the turn.
func apply_normal_move(from: String, to: String) -> void:
	if connection_type == Enums.ConnectionType.LAN and player_color == get_active_turn():
		WorkerThreadPool.add_task(send_move_msg_to_lan_opponent.bind(Enums.MoveType.NORMAL, from, to))

	chess_logic.apply_normal_move(from, to)


func apply_en_passant_move(from: String, to: String) -> void:
	if connection_type == Enums.ConnectionType.LAN and player_color == get_active_turn():
		WorkerThreadPool.add_task(send_move_msg_to_lan_opponent.bind(Enums.MoveType.EN_PASSANT, from, to))

	chess_logic.apply_en_passant_move(from, to)


func apply_castling_move(from: String, to: String) -> void:
	if connection_type == Enums.ConnectionType.LAN and player_color == get_active_turn():
		WorkerThreadPool.add_task(send_move_msg_to_lan_opponent.bind(Enums.MoveType.CASTLING, from, to))

	chess_logic.apply_castling_move(from, to)


func update_promotion_move_squares_data(from: String, to: String) -> void:
	promotion_move_data.set("from", from)
	promotion_move_data.set("to", to)


func update_promotion_move_role_data(role: Enums.PieceRole) -> void:
	promotion_move_data.set("role", role)


func apply_promotion_move() -> void:
	var from: String = promotion_move_data.get("from")
	var to: String = promotion_move_data.get("to")
	var role: Enums.PieceRole = promotion_move_data.get("role")

	if connection_type == Enums.ConnectionType.LAN and player_color == get_active_turn():
		WorkerThreadPool.add_task(send_move_msg_to_lan_opponent.bind(Enums.MoveType.PROMOTION, from, to, role))

	chess_logic.apply_promotion_move(from, to, role)

	promotion_move_data.set("from", "")
	promotion_move_data.set("to", "")
	promotion_move_data.set("role", Enums.PieceRole.EMPTY)


func apply_put_move(role: Enums.PieceRole, square: String) -> void:
	if connection_type == Enums.ConnectionType.LAN and player_color == get_active_turn():
		WorkerThreadPool.add_task(send_move_msg_to_lan_opponent.bind(Enums.MoveType.PUT, " ", square, role))

	chess_logic.apply_put_move(role, square)


func send_move_msg_to_lan_opponent(move_type: Enums.MoveType, from: String, to: String, promotion_or_put_role: Enums.PieceRole = Enums.PieceRole.EMPTY) -> void:
	lan_stream.send_move_msg_to_opponent(move_type, from, to, promotion_or_put_role)


func _on_move_applied(_move_type: Enums.MoveType, _from: String, _to: String) -> void:
	set_active_turn(chess_logic.active_turn() as Enums.ChessColor)


func _on_promotion_piece_updated(_from: String, _to: String, _role: Enums.PieceRole) -> void:
	set_active_turn(chess_logic.active_turn() as Enums.ChessColor)


func _on_put_move_applied(_role: Enums.PieceRole, _to: String) -> void:
	set_active_turn(chess_logic.active_turn() as Enums.ChessColor)


func _on_undo_last_move_applied(_double_undo: bool) -> void:
	set_active_turn(chess_logic.active_turn() as Enums.ChessColor)

	if get_position_history_count() <= 0:
		hud_elements_node.hide_undo_button()


func _on_move_animation_finished() -> void:
	var match_finish_state: Enums.MatchFinishedState = get_match_finished_state()
	if match_finish_state != Enums.MatchFinishedState.NOT_FINISHED:
		match_finished(match_finish_state)
		return

	match connection_type:
		Enums.ConnectionType.LOCAL:
			match local_opponent:
				Enums.LocalOpponent.HUMAN:
					if get_position_history_count() > 0: hud_elements_node.show_undo_button()
				Enums.LocalOpponent.AI:
					if player_color != get_active_turn():
						play_ai_move()
					match player_color:
						Enums.ChessColor.WHITE:
							if get_position_history_count() > 0: hud_elements_node.show_undo_button()
						Enums.ChessColor.BLACK:
							if get_position_history_count() > 1: hud_elements_node.show_undo_button()
		Enums.ConnectionType.LAN:
			if is_undo_requested:
				is_undo_requested = false
			else:
				match player_color:
					Enums.ChessColor.WHITE:
						if get_position_history_count() > 0: hud_elements_node.show_undo_button()
					Enums.ChessColor.BLACK:
						if get_position_history_count() > 1: hud_elements_node.show_undo_button()


func play_ai_move() -> void:
	is_local_ai_thinking = true

	var white_time: int = 0
	var black_time: int = 0

	if is_timed_game:
		white_time = time_node.get_white_time_left()
		black_time = time_node.get_black_time_left()

	WorkerThreadPool.add_task(calculate_best_ai_move_in_thread.bind(white_time, black_time))


func calculate_best_ai_move_in_thread(white_time: int, black_time: int) -> void:
	var best_ai_move: String = chess_logic.best_ai_move(white_time, black_time)
	call_deferred("_on_ai_move_ready", best_ai_move)


func _on_ai_move_ready(best_ai_move: String) -> void:
	if !best_ai_move.is_empty():
		chess_logic.play_ai_move(best_ai_move)
	is_local_ai_thinking = false


func _on_promotion_move_played_by_ai(from: String, to: String, role: Enums.PieceRole) -> void:
	update_promotion_move_squares_data(from, to)
	update_promotion_move_role_data(role)
	board_node.apply_promotion_move(from, to)
	apply_promotion_move()


func _on_white_times_up() -> void:
	match_finished(Enums.MatchFinishedState.BLACK_WON)


func _on_black_times_up() -> void:
	match_finished(Enums.MatchFinishedState.WHITE_WON)


func match_finished(finished_state: Enums.MatchFinishedState) -> void:
	Sound.finish.play()
	if promotion_selection_node.visible:
		promotion_selection_node.hide()

	match finished_state:
		Enums.MatchFinishedState.FINISHED_DRAW:
			match_finished_node.get_node("Label").text = "Game Drawn"
		Enums.MatchFinishedState.WHITE_WON:
			match_finished_node.get_node("Label").text = "White Wins"
		Enums.MatchFinishedState.BLACK_WON:
			match_finished_node.get_node("Label").text = "Black Wins"
	match_finished_node.show()


func get_active_turn() -> Enums.ChessColor:
	return active_turn


func set_active_turn(value: Enums.ChessColor) -> void:
	active_turn = value


func get_active_board_fen() -> String:
	return chess_logic.active_board_fen()

func get_piece_role_from_square(square: String) -> Enums.PieceRole:
	return chess_logic.piece_role_from_square(square) as Enums.PieceRole


func get_piece_role_from_square_in_put_move(square: String) -> Enums.PieceRole:
	return chess_logic.piece_role_from_square_in_put_move(square) as Enums.PieceRole


func get_piece_color_from_square(square: String) -> Enums.ChessColor:
	return chess_logic.piece_color_from_square(square) as Enums.ChessColor


func get_crazyhouse_pockets() -> Array[Vector3i]: # x = color, y = role, z = value
	return chess_logic.crazyhouse_pockets()


func get_legal_moves_from_square(square: String) -> Dictionary[String, Enums.MoveType]:
	return chess_logic.legal_moves_from_square(square) as Dictionary[String, Enums.MoveType]


func get_legal_put_moves_from_role(piece_role: Enums.PieceRole) -> PackedStringArray:
	return chess_logic.legal_put_moves_from_role(piece_role)


func get_king_in_danger_square() -> String:
	return chess_logic.king_in_danger_square()


func get_white_checks() -> int:
	return chess_logic.white_checks()


func get_black_checks() -> int:
	return chess_logic.black_checks()


func get_match_finished_state() -> Enums.MatchFinishedState:
	return chess_logic.match_finished_state() as Enums.MatchFinishedState


func get_position_history_count() -> int:
	return chess_logic.position_history_count()


func is_undoable() -> bool:
	if is_undo_requested:
		return false

	if connection_type == Enums.ConnectionType.LOCAL:
		return get_position_history_count() > 0
	else:
		match player_color:
			Enums.ChessColor.WHITE:
				return get_position_history_count() > 0
			Enums.ChessColor.BLACK:
				return get_position_history_count() > 1
			_:
				return false


func undo_last_move() -> void:
	hud_elements_node.hide_undo_button()

	if connection_type == Enums.ConnectionType.LOCAL:
		if local_opponent == Enums.LocalOpponent.HUMAN:
			chess_logic.undo_last_move(false)
		else:
			if is_local_ai_thinking:
				chess_logic.stop_ai_thinking()

			if player_color == get_active_turn():
				chess_logic.undo_last_move(true)
			else:
				chess_logic.undo_last_move(false)

	elif connection_type == Enums.ConnectionType.LAN:
		is_undo_requested = true
		WorkerThreadPool.add_task(send_undo_request_msg_to_lan_opponent)


func send_undo_request_msg_to_lan_opponent() -> void:
	lan_stream.send_undo_request_msg_to_opponent()


func exit_to_menu() -> void:
	get_tree().change_scene_to_file("uid://dwnbfraut6h7t")


func _exit_tree() -> void:
	if !is_game_started:
		return
	if connection_type == Enums.ConnectionType.LOCAL:
		if local_opponent == Enums.LocalOpponent.AI and is_local_ai_thinking:
			chess_logic.stop_ai_thinking()
	else:
		lan_stream.leave_stream()
		listen_lan_opponent_thread.wait_to_finish()
