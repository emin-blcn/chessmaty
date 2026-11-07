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
var is_waiting_for_undo_response: bool = false
var promotion_move_info: Dictionary[String, Variant] = {"from": "", "to": "", "role": Enums.PieceRole.EMPTY}

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
@onready var game_config_node: TabContainer = $game_config


func _ready() -> void:
	game_config_node.get_node("local_game").config_finished.connect(_on_game_config_finished)
	game_config_node.get_node("lan_game").config_finished.connect(_on_game_config_finished)
	
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
	chess_logic.undo_last_move_applied.connect(hud_elements_node._on_undo_last_move_applied)
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
	
	crazy_house_node.piece_selected_for_put_move.connect(board_node._on_piece_selected_for_put_move)
	crazy_house_node.piece_unselected_for_put_move.connect(board_node._on_piece_unselected_for_put_move)


func _on_game_config_finished(new_config_data: Dictionary[String, Variant]) -> void:
	is_game_started = true
	player_color = new_config_data["player_color"]
	game_mode = new_config_data["game_mode"]
	connection_type = new_config_data["connection_type"]
	if connection_type == Enums.ConnectionType.LOCAL:
		local_opponent = new_config_data["local_opponent"]
	is_timed_game = new_config_data["time_per_side"] != -60_000
	
	chess_logic.config(new_config_data)
	hud_elements_node.config(new_config_data)
	promotion_selection_node.config(new_config_data)
	time_node.config(new_config_data)
	three_check_node.config(new_config_data)
	crazy_house_node.config(new_config_data)
	board_node.config(new_config_data)
	
	if connection_type == Enums.ConnectionType.LOCAL:
		opponent_left_node.queue_free()
		
		match local_opponent:
			Enums.LocalOpponent.HUMAN:
				board_node.enable_board_input()
			Enums.LocalOpponent.AI:
				# AI will make first move in local game if player color is black and opponent is AI
				match player_color:
					Enums.ChessColor.WHITE:
						board_node.enable_board_input()
					Enums.ChessColor.BLACK:
						play_ai_move()
	elif connection_type == Enums.ConnectionType.LAN:
		if player_color == Enums.ChessColor.WHITE:
			board_node.enable_board_input()
		listen_lan_opponent_thread = Thread.new()
		listen_lan_opponent_thread.start(wait_for_lan_opponent_msg)
	
	game_content_node.show()
	game_config_node.queue_free()


func init_stream(new_stream) -> void:
	lan_stream = new_stream


func wait_for_lan_opponent_msg() -> void:
	while true:
		var received_text: String = lan_stream.wait_for_opponent_msg()
		if received_text.is_empty():
			call_deferred("_on_received_leave_msg_from_lan_opponent")
			break
		
		var received_json_data: Dictionary = JSON.parse_string(received_text)
		var received_msg_type: String = received_json_data.get("msg_type")
		var received_params: Dictionary = received_json_data.get("params")
		
		match received_msg_type:
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
	
	if player_color == active_turn or get_position_history_count() == 1:
		chess_logic.undo_last_move(false)
	else:
		chess_logic.undo_last_move(true)
	
	board_node.update_all_pieces()
	board_node.enable_board_input()
	if is_undoable():
		hud_elements_node.show_undo_button()
	received_undo_request_node.hide()
	is_waiting_for_undo_response = false


func reject_undo_request() -> void:
	lan_stream.send_undo_response_msg_to_opponent(false)
	board_node.enable_board_input()
	hud_elements_node.show_undo_button()
	received_undo_request_node.hide()
	is_waiting_for_undo_response = false


func _on_received_undo_response_msg_from_lan_opponent(undo_request_accepted: bool) -> void:
	if undo_request_accepted:
		if player_color != active_turn or get_position_history_count() == 1:
			chess_logic.undo_last_move(false)
		else:
			chess_logic.undo_last_move(true)
	
		board_node.update_all_pieces()
	hud_elements_node._on_responded_undo_request(undo_request_accepted)
	board_node.enable_board_input()
	if is_undoable():
		hud_elements_node.show_undo_button()
	is_waiting_for_undo_response = false


func _on_received_move_msg_from_lan_opponent(move_type: Enums.MoveType, from: String, to: String, promotion_or_put_role: Enums.PieceRole) -> void:
	match move_type:
		Enums.MoveType.NORMAL:
			apply_normal_move(from, to)
		Enums.MoveType.EN_PASSANT:
			apply_en_passant_move(from, to)
		Enums.MoveType.CASTLING:
			apply_castling_move(from, to)
		Enums.MoveType.PROMOTION:
			update_promotion_move_squares(from, to)
			update_promotion_move_role(promotion_or_put_role)
			board_node.apply_promotion_move(from, to)
			apply_promotion_move()
		Enums.MoveType.PUT:
			apply_put_move(promotion_or_put_role, to)


# Note: when chess_logic.apply_*_move() functions are called, switches the turn.
# some tasks must be execute before switching the turn.
func apply_normal_move(from: String, to: String) -> void:
	if connection_type == Enums.ConnectionType.LAN and player_color == active_turn:
		WorkerThreadPool.add_task(send_move_msg_to_lan_opponent.bind(Enums.MoveType.NORMAL, from, to))
	
	chess_logic.apply_normal_move(from, to)


func apply_en_passant_move(from: String, to: String) -> void:
	if connection_type == Enums.ConnectionType.LAN and player_color == active_turn:
		WorkerThreadPool.add_task(send_move_msg_to_lan_opponent.bind(Enums.MoveType.EN_PASSANT, from, to))
	
	chess_logic.apply_en_passant_move(from, to)


func apply_castling_move(from: String, to: String) -> void:
	if connection_type == Enums.ConnectionType.LAN and player_color == active_turn:
		WorkerThreadPool.add_task(send_move_msg_to_lan_opponent.bind(Enums.MoveType.CASTLING, from, to))
	
	chess_logic.apply_castling_move(from, to)


func update_promotion_move_squares(from: String, to: String) -> void:
	promotion_move_info.set("from", from)
	promotion_move_info.set("to", to)


func update_promotion_move_role(role: Enums.PieceRole) -> void:
	promotion_move_info.set("role", role)


func apply_promotion_move() -> void:
	var from: String = promotion_move_info.get("from")
	var to: String = promotion_move_info.get("to")
	var role: Enums.PieceRole = promotion_move_info.get("role")
	
	if connection_type == Enums.ConnectionType.LAN and player_color == active_turn:
		WorkerThreadPool.add_task(send_move_msg_to_lan_opponent.bind(Enums.MoveType.PROMOTION, from, to, role))
	
	chess_logic.apply_promotion_move(from, to, role)
	
	promotion_move_info.set("from", "")
	promotion_move_info.set("to", "")
	promotion_move_info.set("role", Enums.PieceRole.EMPTY)


func apply_put_move(role: Enums.PieceRole, square: String) -> void:
	if connection_type == Enums.ConnectionType.LAN and player_color == active_turn:
		WorkerThreadPool.add_task(send_move_msg_to_lan_opponent.bind(Enums.MoveType.PUT, " ", square, role))
	
	chess_logic.apply_put_move(role, square)


func send_move_msg_to_lan_opponent(move_type: Enums.MoveType, from: String, to: String, promotion_or_put_role: Enums.PieceRole = Enums.PieceRole.EMPTY) -> void:
	lan_stream.send_move_msg_to_opponent(move_type, from, to, promotion_or_put_role)


func _on_move_applied(_move_type: Enums.MoveType, _from: String, _to: String) -> void:
	active_turn = get_turn()


func _on_promotion_piece_updated(_from: String, _to: String, _role: Enums.PieceRole) -> void:
	active_turn = get_turn()


func _on_put_move_applied(_role: Enums.PieceRole, _to: String) -> void:
	active_turn = get_turn()


func _on_undo_last_move_applied(_double_undo: bool) -> void:
	active_turn = get_turn()
	if match_finished_node.visible:
		match_finished_node.hide()


func _on_move_animation_finished() -> void:
	var match_finish_state: Enums.MatchFinishedState = get_match_finished_state()
	if match_finish_state != Enums.MatchFinishedState.NOT_FINISHED:
		match_finished(match_finish_state)
		return
	
	match connection_type:
		Enums.ConnectionType.LOCAL:
			if get_position_history_count() > 0:
				hud_elements_node.show_undo_button()
			
			if local_opponent == Enums.LocalOpponent.HUMAN:
				# opponenet is local human, turn isn't important, allow to make move
				board_node.enable_board_input()
			else: # opponent is AI
				if player_color == active_turn:
					# it'a human's turn, allow to make move
					board_node.enable_board_input()
				else:
					# it'a AI's turn, don't allow to make move, AI will make move
					play_ai_move()
		Enums.ConnectionType.LAN:
			if player_color == active_turn:
				board_node.enable_board_input()
				if get_position_history_count() > 1:
					hud_elements_node.show_undo_button()
			else:
				hud_elements_node.show_undo_button()


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
	update_promotion_move_squares(from, to)
	update_promotion_move_role(role)
	
	board_node.apply_promotion_move(from, to)
	apply_promotion_move()


func _on_white_times_up() -> void:
	match_finished(Enums.MatchFinishedState.BLACK_WON)


func _on_black_times_up() -> void:
	match_finished(Enums.MatchFinishedState.WHITE_WON)


func match_finished(finished_state: Enums.MatchFinishedState) -> void:
	board_node.input_control_node.hide()
	Sound.finish.play()
	match finished_state:
		Enums.MatchFinishedState.FINISHED_DRAW:
			match_finished_node.get_node("Label").text = "Game Drawn"
		Enums.MatchFinishedState.WHITE_WON:
			match_finished_node.get_node("Label").text = "White Wins"
		Enums.MatchFinishedState.BLACK_WON:
			match_finished_node.get_node("Label").text = "Black Wins"
	match_finished_node.show()


func get_connection_type() -> Enums.ConnectionType:
	return connection_type


func get_turn() -> Enums.ChessColor:
	return chess_logic.turn() as Enums.ChessColor


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
	if get_position_history_count() <= 0 or board_node.is_move_animation_playing():
		return false
	
	if is_waiting_for_undo_response:
		return false
	
	return get_position_history_count() > 0 and !board_node.is_move_animation_playing()


func undo_last_move() -> void:
	if !is_undoable():
		return
	
	board_node.disable_board_input()
	hud_elements_node.hide_undo_button()
	
	if connection_type == Enums.ConnectionType.LOCAL:
		if local_opponent == Enums.LocalOpponent.HUMAN:
			chess_logic.undo_last_move(false)
		else:
			if is_local_ai_thinking:
				chess_logic.stop_ai_thinking()
			
			if active_turn == player_color:
				chess_logic.undo_last_move(true)
			else:
				chess_logic.undo_last_move(false)
		
		board_node.update_all_pieces()
		board_node.enable_board_input()
		
		if is_undoable():
			hud_elements_node.show_undo_button()
		
	elif connection_type == Enums.ConnectionType.LAN:
		is_waiting_for_undo_response = true
		WorkerThreadPool.add_task(send_undo_request_msg_to_lan_opponent)


func send_undo_request_msg_to_lan_opponent() -> void:
	lan_stream.send_undo_request_msg_to_opponent()


func exit_to_menu() -> void:
	get_tree().change_scene_to_file("uid://dwnbfraut6h7t")


func _exit_tree() -> void:
	if !is_game_started:
		return
	if is_local_ai_thinking:
		chess_logic.stop_ai_thinking()
	elif connection_type == Enums.ConnectionType.LAN:
		lan_stream.leave_stream()
		listen_lan_opponent_thread.wait_to_finish()
