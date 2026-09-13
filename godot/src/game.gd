extends Control

const MOVE_MSG: String = "CHESSMATY_MOVE"
const UNDO_REQUEST_MSG: String = "CHESSMATY_UNDO_REQUEST"
const UNDO_RESPONSE_MSG: String = "CHESSMATY_UNDO_RESPONSE"

@onready var game_content_node: Control = $game_content
@onready var board_node: Control = $game_content/board
@onready var hud_node: Control = $game_content/hud
@onready var move_history_table_node: Panel = $game_content/hud/move_history_table
@onready var promotion_selection_node: TextureRect = $game_content/hud/promotion_selection
@onready var received_undo_request_node: TextureRect = $game_content/hud/received_undo_request
@onready var match_finished_node: Control = $game_content/hud/match_finished
@onready var opponent_left_node: TextureRect = $game_content/hud/opponent_left
@onready var time_control_node: Control = $game_content/hud/time_control
@onready var three_check_node: Control = $game_content/hud/three_check
@onready var crazy_house_node: Control = $game_content/hud/crazy_house
@onready var game_config_node: TabContainer = $game_config

var player_color: Enums.ChessColor
var game_mode: Enums.GameMode
var connection_type: Enums.ConnectionType
var local_opponent: Enums.LocalOpponent
var is_timed_game: bool
var chess_logic: ChessLogic = ChessLogic.new()
var listen_lan_opponent_thread: Thread
var lan_stream # host or peer is possible
var current_turn: Enums.ChessColor = Enums.ChessColor.WHITE
var is_game_started: bool = false
var is_local_ai_thinking: bool = false
var is_waiting_for_undo_response: bool = false
var promotion_pawn_from_to_square: String
var ai_selected_promotion_role: Enums.Piece


func _ready() -> void:
	game_config_node.get_node("local_game").config_finished.connect(_on_game_config_finished)
	game_config_node.get_node("lan_game").config_finished.connect(_on_game_config_finished)
	
	board_node.move_animation_started.connect(_on_move_animation_started)
	board_node.move_animation_started.connect(hud_node._on_move_animation_started)
	board_node.move_animation_started.connect(move_history_table_node._on_move_animation_started)
	board_node.move_animation_started.connect(time_control_node._on_move_animation_started)
	board_node.move_animation_started.connect(crazy_house_node._on_move_animation_started)
	
	board_node.move_animation_finished.connect(_on_move_animation_finished)
	board_node.move_animation_finished.connect(promotion_selection_node._on_move_animation_finished)
	board_node.move_animation_finished.connect(time_control_node._on_move_animation_finished)
	board_node.move_animation_finished.connect(three_check_node._on_move_animation_finished)
	
	time_control_node.white_times_up.connect(_on_white_times_up)
	time_control_node.black_times_up.connect(_on_black_times_up)
	
	chess_logic.move_applied.connect(board_node._on_chess_logic_move_applied)


func _on_game_config_finished(new_config_data: Dictionary[String, Variant]) -> void:
	is_game_started = true
	player_color = new_config_data["player_color"]
	game_mode = new_config_data["game_mode"]
	connection_type = new_config_data["connection_type"]
	local_opponent = new_config_data["local_opponent"]
	is_timed_game = new_config_data["time_per_side"] != -60_000
	
	chess_logic.config(new_config_data)
	hud_node.config(new_config_data)
	promotion_selection_node.config(new_config_data)
	time_control_node.config(new_config_data)
	three_check_node.config(new_config_data)
	crazy_house_node.config(new_config_data)
	board_node.config(new_config_data)
	
	if connection_type == Enums.ConnectionType.LOCAL:
		opponent_left_node.queue_free()
		
		match local_opponent:
			Enums.LocalOpponent.HUMAN:
				board_node.show_input_control_node()
			Enums.LocalOpponent.AI:
				# AI will make first move in local game if player color is black and opponent is AI
				match player_color:
					Enums.ChessColor.WHITE:
						board_node.show_input_control_node()
					Enums.ChessColor.BLACK:
						play_ai_move()
	elif connection_type == Enums.ConnectionType.LAN:
		if player_color == Enums.ChessColor.WHITE:
			board_node.show_input_control_node()
		listen_lan_opponent_thread = Thread.new()
		listen_lan_opponent_thread.start(wait_for_lan_opponent_msg)
	
	game_content_node.show()
	game_config_node.queue_free()


func init_stream(new_stream) -> void:
	lan_stream = new_stream


func wait_for_lan_opponent_msg() -> void:
	while true:
		var received_msg: String = lan_stream.wait_for_opponent_msg()
		if received_msg.is_empty():
			call_deferred("_on_received_leave_msg_from_lan_opponent")
			break
		elif received_msg.begins_with(MOVE_MSG):
			call_deferred("_on_received_move_msg_from_lan_opponent", received_msg)
		elif received_msg.begins_with(UNDO_REQUEST_MSG):
			call_deferred("_on_received_undo_request_msg_from_lan_opponent")
		elif received_msg.begins_with(UNDO_RESPONSE_MSG):
			call_deferred("_on_received_undo_response_msg_from_lan_opponent", received_msg)


func _on_received_leave_msg_from_lan_opponent() -> void:
	if !match_finished_node.visible:
		opponent_left_node.show()


func _on_received_undo_request_msg_from_lan_opponent() -> void:
	if !match_finished_node.visible:
		received_undo_request_node.show()


func accept_undo_request() -> void:
	lan_stream.send_undo_response_msg_to_opponent(true)
	
	if player_color == current_turn or get_position_history_count() == 1:
		chess_logic.undo_last_move()
	else:
		chess_logic.undo_last_move()
		chess_logic.undo_last_move()
	
	board_node.update_all_pieces()
	board_node.show_input_control_node()
	if is_undoable():
		hud_node.show_undo_button()
	received_undo_request_node.hide()
	is_waiting_for_undo_response = false


func reject_undo_request() -> void:
	lan_stream.send_undo_response_msg_to_opponent(false)
	board_node.show_input_control_node()
	hud_node.show_undo_button()
	received_undo_request_node.hide()
	is_waiting_for_undo_response = false


func _on_received_undo_response_msg_from_lan_opponent(received_undo_response_msg: String) -> void:
	var is_undo_request_accepted = received_undo_response_msg.split("|")[1] == "true"
	
	if is_undo_request_accepted:
		if player_color != current_turn or get_position_history_count() == 1:
			chess_logic.undo_last_move()
		else:
			chess_logic.undo_last_move()
			chess_logic.undo_last_move()
	
		board_node.update_all_pieces()
	hud_node._on_responded_undo_request(is_undo_request_accepted)
	board_node.show_input_control_node()
	if is_undoable():
		hud_node.show_undo_button()
	is_waiting_for_undo_response = false


func _on_received_move_msg_from_lan_opponent(received_move_msg: String) -> void:
	var msg_element_array: PackedStringArray = received_move_msg.split("|")
	var move_type: Enums.MoveType = int(msg_element_array[1]) as Enums.MoveType
	var from: String = msg_element_array[2]
	var to: String = msg_element_array[3]
	var promotion_or_put_role: Enums.Piece = int(msg_element_array[4]) as Enums.Piece
	
	match move_type:
		Enums.MoveType.NORMAL:
			apply_normal_move(from, to)
		Enums.MoveType.EN_PASSANT:
			apply_en_passant_move(from, to)
		Enums.MoveType.CASTLING:
			apply_castling_move(from, to)
		Enums.MoveType.PROMOTION:
			promotion_pawn_from_to_square = from + "_" + to
			apply_promotion_move(promotion_or_put_role)
		Enums.MoveType.PUT:
			appy_put_move(promotion_or_put_role, to)


func update_ai_selected_promotion_role(new_role: Enums.Piece) -> void:
	ai_selected_promotion_role = new_role


# Note: when chess_logic.apply_*_move() functions are called, switches the turn.
# some tasks must be execute before switching the turn.
func apply_normal_move(from: String, to: String) -> void:
	if connection_type == Enums.ConnectionType.LAN and player_color == current_turn:
		WorkerThreadPool.add_task(send_move_msg_to_lan_opponent.bind(Enums.MoveType.NORMAL, from, to))
	
	chess_logic.apply_normal_move(from, to)


func apply_en_passant_move(from: String, to: String) -> void:
	if connection_type == Enums.ConnectionType.LAN and player_color == current_turn:
		WorkerThreadPool.add_task(send_move_msg_to_lan_opponent.bind(Enums.MoveType.EN_PASSANT, from, to))
	
	chess_logic.apply_en_passant_move(from, to)


func apply_castling_move(from: String, to: String) -> void:
	if connection_type == Enums.ConnectionType.LAN and player_color == current_turn:
		WorkerThreadPool.add_task(send_move_msg_to_lan_opponent.bind(Enums.MoveType.CASTLING, from, to))
	
	chess_logic.apply_castling_move(from, to)


func apply_promotion_move(new_role: Enums.Piece) -> void:
	var array: PackedStringArray = promotion_pawn_from_to_square.split("_")
	promotion_pawn_from_to_square = ""
	ai_selected_promotion_role = Enums.Piece.EMPTY
	
	var from: String = array[0]
	var to: String = array[1]
	
	if connection_type == Enums.ConnectionType.LAN and player_color == current_turn:
		WorkerThreadPool.add_task(send_move_msg_to_lan_opponent.bind(Enums.MoveType.PROMOTION, from, to, new_role))
	
	chess_logic.apply_promotion_move(from, to, new_role)


func appy_put_move(role: Enums.Piece, square: String) -> void:
	if connection_type == Enums.ConnectionType.LAN and player_color == current_turn:
		WorkerThreadPool.add_task(send_move_msg_to_lan_opponent.bind(Enums.MoveType.PUT, " ", square, role))
	
	chess_logic.apply_put_move(role, square)
	crazy_house_node._on_put_move_applied()


func send_move_msg_to_lan_opponent(move_type: Enums.MoveType, from_square: String, to_square: String, promotion_new_role: Enums.Piece = Enums.Piece.QUEEN) -> void:
	lan_stream.send_move_msg_to_opponent(move_type, from_square, to_square, promotion_new_role)


func _on_selected_piece_for_put_move(piece_role: Enums.Piece) -> void:
	board_node._on_selected_piece_for_put_move(piece_role)


func _on_unselected_piece_for_put_move() -> void:
	board_node._on_unselected_piece_for_put_move()


func _on_move_animation_started(move_type: Enums.MoveType, from: String, to: String) -> void:
	current_turn = get_turn()
	
	if move_type == Enums.MoveType.UNDO:
		if match_finished_node.visible:
			match_finished_node.hide()
	elif move_type == Enums.MoveType.PROMOTION_REQUEST_BY_HUMAN or move_type == Enums.MoveType.PROMOTION_REQUEST_BY_AI:
		promotion_pawn_from_to_square = from + "_" + to


func _on_move_animation_finished(move_type: Enums.MoveType) -> void:
	if move_type == Enums.MoveType.UNDO:
		return
	elif move_type == Enums.MoveType.PROMOTION_REQUEST_BY_AI:
		apply_promotion_move(ai_selected_promotion_role)
	
	var match_finish_state: Enums.MatchFinishedState = get_match_finished_state()
	if match_finish_state != Enums.MatchFinishedState.NOT_FINISHED:
		match_finished(match_finish_state)
		return
	
	match connection_type:
		Enums.ConnectionType.LOCAL:
			# local game
			if local_opponent == Enums.LocalOpponent.HUMAN:
				# opponenet is local human, turn isn't important, allow to make move
				board_node.show_input_control_node()
				hud_node.show_undo_button()
			else:
				# opponent is AI
				if player_color == current_turn:
					# it'a human's turn, allow to make move
					board_node.show_input_control_node()
					hud_node.show_undo_button()
				else:
					# it'a AI's turn, don't allow to make move, AI will make move
					play_ai_move()
		Enums.ConnectionType.LAN:
			if player_color == current_turn:
				board_node.show_input_control_node()
				if get_position_history_count() > 1:
					hud_node.show_undo_button()
			else:
				hud_node.show_undo_button()


func play_ai_move() -> void:
	var white_time: int = 0
	var black_time: int = 0
	
	if is_timed_game:
		white_time = time_control_node.get_white_time_left()
		black_time = time_control_node.get_black_time_left()
	
	is_local_ai_thinking = true
	WorkerThreadPool.add_task(calculate_best_ai_move_in_thread.bind(white_time, black_time))


func calculate_best_ai_move_in_thread(white_time: int, black_time: int) -> void:
	var best_move: String = chess_logic.best_ai_move(white_time, black_time)
	call_deferred("_on_ai_move_ready", best_move)


func _on_ai_move_ready(best_ai_move: String) -> void:
	chess_logic.play_ai_move(best_ai_move)
	is_local_ai_thinking = false


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


func get_piece_role_from_square(square: String) -> Enums.Piece:
	return chess_logic.piece_role_from_square(square) as Enums.Piece


func get_piece_role_from_square_in_put_move(square: String) -> Enums.Piece:
	return chess_logic.piece_role_from_square_in_put_move(square) as Enums.Piece


func get_piece_color_from_square(square: String) -> Enums.ChessColor:
	return chess_logic.piece_color_from_square(square) as Enums.ChessColor


func get_crazyhouse_pocket_white_pieces() -> Dictionary[Enums.Piece, int]:
	return chess_logic.crazyhouse_pocket_white_pieces() as Dictionary[Enums.Piece, int]


func get_crazyhouse_pocket_black_pieces() -> Dictionary[Enums.Piece, int]:
	return chess_logic.crazyhouse_pocket_black_pieces() as Dictionary[Enums.Piece, int]


func get_legal_moves_from_square(square: String) -> Dictionary[String, Enums.MoveType]:
	return chess_logic.legal_moves_from_square(square) as Dictionary[String, Enums.MoveType]


func get_legal_put_moves_from_role(piece_role: Enums.Piece) -> PackedStringArray:
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
	if connection_type == Enums.ConnectionType.LOCAL:
		if local_opponent == Enums.LocalOpponent.HUMAN:
			return get_position_history_count() > 0 and !board_node.is_move_animation_playing() and !is_local_ai_thinking
		else:
			return get_position_history_count() > 1 and !board_node.is_move_animation_playing() and !is_local_ai_thinking
	
	if is_waiting_for_undo_response:
		return false
	
	return get_position_history_count() > 0 and !board_node.is_move_animation_playing()


func undo_last_move() -> void:
	if !is_undoable():
		return
	
	board_node.hide_input_control_node()
	hud_node.hide_undo_button()
	board_node.clear_markers()
	
	if connection_type == Enums.ConnectionType.LOCAL:
		if local_opponent == Enums.LocalOpponent.HUMAN:
			chess_logic.undo_last_move()
		else:
			chess_logic.undo_last_move()
			chess_logic.undo_last_move()
		
		board_node.update_all_pieces()
		board_node.show_input_control_node()
		
		if is_undoable():
			hud_node.show_undo_button()
		
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
