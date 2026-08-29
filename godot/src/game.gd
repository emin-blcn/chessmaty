extends Control

@onready var game_content_node: Control = $game_content
@onready var board_node: Control = $game_content/board
@onready var move_history_table_node: Panel = $game_content/hud/move_history_table
@onready var promotion_selection_node: TextureRect = $game_content/hud/promotion_selection
@onready var match_finished_node: Control = $game_content/hud/match_finished
@onready var lan_opponent_left_node: TextureRect = $game_content/hud/lan_opponent_left
@onready var time_control_node: Control = $game_content/hud/time_control
@onready var three_check_control_node: Control = $game_content/hud/three_check_control
@onready var game_config_node: TabContainer = $game_config

var config_data: Dictionary[String, Variant] = {}
var chess_logic: ChessLogic = ChessLogic.new()
var listen_lan_opponent_thread: Thread = null
var stream
var local_ai_is_thinking: bool = false
var promotion_pawn_from_to_square: String
var ai_selected_promotion_role: Enums.Piece


func _ready() -> void:
	game_config_node.get_node("local_game").config_finished.connect(_on_game_config_finished)
	game_config_node.get_node("lan_game").config_finished.connect(_on_game_config_finished)
	
	board_node.move_animation_started.connect(_on_move_animation_started)
	board_node.move_animation_started.connect(move_history_table_node._on_move_animation_started)
	board_node.move_animation_started.connect(time_control_node._on_move_animation_started)
	
	board_node.move_animation_finished.connect(_on_move_animation_finished)
	board_node.move_animation_finished.connect(promotion_selection_node._on_move_animation_finished)
	board_node.move_animation_finished.connect(time_control_node._on_move_animation_finished)
	board_node.move_animation_finished.connect(three_check_control_node._on_move_animation_finished)
	
	time_control_node.white_times_up.connect(_on_white_times_up)
	time_control_node.black_times_up.connect(_on_black_times_up)
	
	chess_logic.move_applied.connect(board_node._on_chess_logic_move_applied)


func _on_game_config_finished(new_config_data: Dictionary[String, Variant]):
	config_data = new_config_data
	
	chess_logic.config(config_data)
	promotion_selection_node.config(config_data)
	if config_data["time_per_side"] == -60_000:
		time_control_node.queue_free()
	else:
		time_control_node.config(config_data)
	three_check_control_node.config(config_data)
	board_node.config(config_data)
	
	game_content_node.show()
	game_config_node.queue_free()
	
	match config_data["connection_type"]:
		Enums.ConnectionType.LOCAL:
			lan_opponent_left_node.queue_free()
			match config_data["local_opponent"]:
				Enums.LocalOpponent.HUMAN:
					board_node.show_input_control_node()
				Enums.LocalOpponent.AI:
					# AI will make first move in local game if player color is black and opponent is AI
					match config_data["player_color"]:
						Enums.ChessColor.WHITE:
							board_node.show_input_control_node()
						Enums.ChessColor.BLACK:
							play_ai_move()
		Enums.ConnectionType.LAN:
			if config_data["player_color"] == Enums.ChessColor.WHITE:
				board_node.show_input_control_node()
			listen_lan_opponent_thread = Thread.new()
			listen_lan_opponent_thread.start(wait_for_opponent_msg)


func init_stream(new_stream):
	stream = new_stream


func wait_for_opponent_msg():
	while true:
		var received_msg: String = stream.wait_for_opponent_msg()
		if received_msg.is_empty():
			lan_opponent_left_node.call_deferred("show")
			break
		
		call_deferred("_on_received_opponent_msg", received_msg)


func _on_received_opponent_msg(received_msg: String):
	var msg_element_array: PackedStringArray = received_msg.split("|")
	var move_type: Enums.MoveType = int(msg_element_array[1]) as Enums.MoveType
	var from: String = msg_element_array[2]
	var to: String = msg_element_array[3]
	var new_promotion_role: Enums.Piece = int(msg_element_array[4]) as Enums.Piece
	
	match move_type:
		Enums.MoveType.NORMAL:
			apply_normal_move(from, to)
		Enums.MoveType.EN_PASSANT:
			apply_en_passant_move(from, to)
		Enums.MoveType.CASTLING:
			apply_castling_move(from, to)
		Enums.MoveType.PROMOTION:
			promotion_pawn_from_to_square = from + "_" + to
			apply_promotion_move(new_promotion_role)


func send_move_msg_to_lan_opponent(move_type: Enums.MoveType, from_square: String, to_square: String, promotion_new_role: Enums.Piece = Enums.Piece.QUEEN):
	stream.send_move_msg_to_opponent(move_type, from_square, to_square, promotion_new_role)


func update_ai_selected_promotion_role(new_role: Enums.Piece):
	ai_selected_promotion_role = new_role


func apply_normal_move(from: String, to: String):
	if config_data["connection_type"] == Enums.ConnectionType.LAN and config_data["player_color"] == get_turn():
		WorkerThreadPool.add_task(send_move_msg_to_lan_opponent.bind(Enums.MoveType.NORMAL, from, to))
	
	chess_logic.apply_normal_move(from, to)


func apply_en_passant_move(from: String, to: String):
	if config_data["connection_type"] == Enums.ConnectionType.LAN and config_data["player_color"] == get_turn():
		WorkerThreadPool.add_task(send_move_msg_to_lan_opponent.bind(Enums.MoveType.EN_PASSANT, from, to))
	
	chess_logic.apply_en_passant_move(from, to)


func apply_castling_move(from: String, to: String):
	if config_data["connection_type"] == Enums.ConnectionType.LAN and config_data["player_color"] == get_turn():
		WorkerThreadPool.add_task(send_move_msg_to_lan_opponent.bind(Enums.MoveType.CASTLING, from, to))
	
	chess_logic.apply_castling_move(from, to)


func apply_promotion_move(new_role: Enums.Piece):
	var array: PackedStringArray = promotion_pawn_from_to_square.split("_")
	promotion_pawn_from_to_square = ""
	ai_selected_promotion_role = Enums.Piece.EMPTY
	
	var from: String = array[0]
	var to: String = array[1]
	
	if config_data["connection_type"] == Enums.ConnectionType.LAN and config_data["player_color"] == get_turn():
		WorkerThreadPool.add_task(send_move_msg_to_lan_opponent.bind(Enums.MoveType.PROMOTION, from, to, new_role))
	
	chess_logic.apply_promotion_move(from, to, new_role)


func _on_move_animation_started(move_type: Enums.MoveType, from: String, to: String):
	if move_type == Enums.MoveType.UNDO:
		if match_finished_node.visible:
			match_finished_node.hide()
	elif move_type == Enums.MoveType.PROMOTION_REQUEST_BY_HUMAN:
		promotion_pawn_from_to_square = from + "_" + to
	elif move_type == Enums.MoveType.PROMOTION_REQUEST_BY_AI:
		promotion_pawn_from_to_square = from + "_" + to


func _on_move_animation_finished(move_type: Enums.MoveType):
	Sounds.move_sfx.play()
	
	if move_type == Enums.MoveType.UNDO:
		return
	elif move_type == Enums.MoveType.PROMOTION_REQUEST_BY_AI:
		apply_promotion_move(ai_selected_promotion_role)
	
	var match_finish_state: Enums.MatchFinishedState = get_match_finished_state()
	if match_finish_state != Enums.MatchFinishedState.NOT_FINISHED:
		match_finished(match_finish_state)
		return
	
	match config_data["connection_type"]:
		Enums.ConnectionType.LOCAL:
			# local game
			if config_data["local_opponent"] == Enums.LocalOpponent.HUMAN:
				# opponenet is local human, turn isn't important, allow to make move
				board_node.show_input_control_node()
			else:
				# opponent is AI
				if config_data["player_color"] == get_turn():
					# it'a human's turn, allow to make move
					board_node.show_input_control_node()
				else:
					# it'a AI's turn, don't allow to make move, AI will make move
					play_ai_move()
		Enums.ConnectionType.LAN:
			if config_data["player_color"] == get_turn():
				board_node.show_input_control_node()


func play_ai_move():
	var white_time: int = 0
	var black_time: int = 0
	
	if config_data["time_per_side"] != -60_000:
		white_time = time_control_node.get_white_time_left()
		black_time = time_control_node.get_black_time_left()
	
	local_ai_is_thinking = true
	WorkerThreadPool.add_task(_thread_calculate_move.bind(white_time, black_time))


func _thread_calculate_move(white_time: int, black_time: int):
	var best_move: String = chess_logic.best_ai_move(white_time, black_time)
	call_deferred("_on_ai_move_ready", best_move)


func _on_ai_move_ready(best_ai_move: String):
	local_ai_is_thinking = false
	chess_logic.play_ai_move(best_ai_move)


func _on_white_times_up():
	match_finished(Enums.MatchFinishedState.BLACK_WON)


func _on_black_times_up():
	match_finished(Enums.MatchFinishedState.WHITE_WON)


func match_finished(finished_state: Enums.MatchFinishedState):
	board_node.input_control_node.hide()
	
	match finished_state:
		Enums.MatchFinishedState.FINISHED_DRAW:
			Sounds.draw_sfx.play()
			match_finished_node.get_node("Label").text = "Game Drawn"
		Enums.MatchFinishedState.WHITE_WON:
			match config_data["player_color"]:
				Enums.ChessColor.WHITE:
					Sounds.victory_sfx.play()
				Enums.ChessColor.BLACK:
					Sounds.defeat_sfx.play()
			match_finished_node.get_node("Label").text = "White Wins"
		Enums.MatchFinishedState.BLACK_WON:
			match config_data["player_color"]:
				Enums.ChessColor.WHITE:
					Sounds.defeat_sfx.play()
				Enums.ChessColor.BLACK:
					Sounds.victory_sfx.play()
			match_finished_node.get_node("Label").text = "Black Wins"
	match_finished_node.show()


func get_connection_type() -> Enums.ConnectionType:
	return config_data["connection_type"]

func get_turn() -> Enums.ChessColor:
	return chess_logic.turn() as Enums.ChessColor


func get_piece_from_square(square: String) -> Enums.Piece:
	return chess_logic.piece_from_square(square) as Enums.Piece


func get_piece_color_from_square(square: String) -> Enums.ChessColor:
	return chess_logic.piece_color_from_square(square) as Enums.ChessColor


func get_legal_moves_from_square(square: String):
	return chess_logic.legal_moves_from_square(square)


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


func _is_undoable() -> bool:
	return chess_logic.is_undoable() and get_position_history_count() >= 1 and !board_node.is_move_animation_playing() and !local_ai_is_thinking


func undo_last_move() -> void:
	if _is_undoable():
		board_node.clear_markers()
		
		if config_data["local_opponent"] == Enums.LocalOpponent.AI:
			if get_position_history_count() == 1:
				chess_logic.undo_last_move()
				board_node.update_all_pieces()
				play_ai_move()
			else:
				chess_logic.undo_last_move()
				chess_logic.undo_last_move()
				board_node.update_all_pieces()
		else:
			chess_logic.undo_last_move()
			board_node.update_all_pieces()
		
		board_node.show_input_control_node()


func exit_to_menu():
	get_tree().change_scene_to_file("uid://dwnbfraut6h7t")


func _exit_tree() -> void:
	if config_data.is_empty():
		return
	if local_ai_is_thinking:
		chess_logic.stop_ai_thinking()
	elif config_data["connection_type"] == Enums.ConnectionType.LAN:
		stream.send_leave_match_msg_to_opponent()
		listen_lan_opponent_thread.wait_to_finish()
