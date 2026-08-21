extends Control

@onready var game_config_node: TabContainer = $game_config_gui
@onready var game_content_node: Control = $game_content
@onready var board_node: Control = $game_content/board
@onready var move_history_table_node: Panel = $game_content/hud/move_history_table
@onready var promotion_selection_node: TextureRect = $game_content/hud/promotion_selection_gui
@onready var match_finished_node: Control = $game_content/hud/match_finished_gui
@onready var time_control_node: Control = $game_content/hud/time_control_gui

var chess_logic: ChessLogic = ChessLogic.new()
var lan_stream: LanStream
var lan_client: LanClient
var config_data: Dictionary[String, Variant] = {}
var promotion_pawn_from_to_square: String
var ai_selected_promotion_role: Enums.Piece
var ai_is_thinking: bool


func _ready() -> void:
	game_config_node.get_node("local_game").config_finished.connect(_on_game_config_finished)
	
	board_node.move_animation_started.connect(self._on_move_animation_started)
	board_node.move_animation_started.connect(move_history_table_node._on_move_animation_started)
	board_node.move_animation_started.connect(time_control_node._on_move_animation_started)
	
	board_node.move_animation_finished.connect(self._on_move_animation_finished)
	board_node.move_animation_finished.connect(promotion_selection_node._on_move_animation_finished)
	board_node.move_animation_finished.connect(time_control_node._on_move_animation_finished)
	
	time_control_node.white_times_up.connect(self._on_white_times_up)
	time_control_node.black_times_up.connect(self._on_black_times_up)
	
	chess_logic.move_applied.connect(board_node._on_chess_logic_move_applied)


func _on_game_config_finished(new_config_data: Dictionary[String, Variant]):
	config_data = new_config_data
	
	chess_logic.config(config_data)
	promotion_selection_node.config(config_data)
	time_control_node.config(config_data)
	board_node.config(config_data)
	
	game_content_node.show()
	game_config_node.queue_free()
	
	match config_data["connection_type"]:
		Enums.ConnectionType.LOCAL:
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
			match config_data["lan_opponent_side"]:
				Enums.LanOpponentSide.STREAM:
					lan_stream = LanStream.new()
				Enums.LanOpponentSide.ClIENT:
					lan_client = LanClient.new()
			match config_data["player_color"]:
				Enums.ChessColor.WHITE:
					board_node.show_input_control_node()


func update_ai_selected_new_promotion_role(ai_selected_new_promotion_role: Enums.Piece):
	ai_selected_promotion_role = ai_selected_new_promotion_role


func apply_normal_move(from: String, to: String):
	chess_logic.apply_normal_move(from, to)


func apply_en_passant_move(from: String, to: String):
	chess_logic.apply_en_passant_move(from, to)


func apply_castling_move(from: String, to: String):
	chess_logic.apply_castling_move(from, to)


func apply_promotion_move(new_role: Enums.Piece):
	var array: PackedStringArray = promotion_pawn_from_to_square.split("_")
	promotion_pawn_from_to_square = ""
	
	var from_square: String = array[0]
	var to_square: String = array[1]
	board_node.update_promotion_piece(to_square, new_role)
	chess_logic.apply_promotion_move(from_square, to_square, new_role)


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
	
	if config_data["connection_type"] == Enums.ConnectionType.LOCAL:
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


func play_ai_move():
	var white_time: int = 0
	var black_time: int = 0
	
	if config_data["time_per_side"] != -60_000:
		white_time = time_control_node.get_white_time_left()
		black_time = time_control_node.get_black_time_left()
	
	ai_is_thinking = true
	WorkerThreadPool.add_task(_thread_calculate_move.bind(white_time, black_time))


func _thread_calculate_move(white_time: int, black_time: int):
	var best_move: String = chess_logic.get_best_ai_move(white_time, black_time)
	call_deferred("_on_ai_move_ready", best_move)


func _on_ai_move_ready(best_ai_move: String):
	ai_is_thinking = false
	chess_logic.play_ai_move(best_ai_move)


func undo_last_move() -> void:
	if is_undoable():
		board_node.clear_move_markers()
		
		if config_data["local_opponent"] == Enums.LocalOpponent.AI:
			if get_move_count() == 1:
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


func get_turn() -> Enums.ChessColor:
	return chess_logic.get_turn() as Enums.ChessColor


func get_piece_from_square(square: String) -> Enums.Piece:
	return chess_logic.get_piece_from_square(square) as Enums.Piece


func get_piece_color_from_square(square: String) -> Enums.ChessColor:
	return chess_logic.get_piece_color_from_square(square) as Enums.ChessColor


func get_legal_moves_from_square(square: String):
	return chess_logic.get_legal_moves_from_square(square)


func get_king_in_dangered_square() -> String:
	return chess_logic.get_king_in_dangered_square()


func get_match_finished_state() -> Enums.MatchFinishedState:
	return chess_logic.get_match_finished_state() as Enums.MatchFinishedState


func get_move_count() -> int:
	return chess_logic.get_move_count()


func is_undoable() -> bool:
	return chess_logic.is_undoable() and get_move_count() >= 1 and !board_node.is_move_animation_playing() and !ai_is_thinking


func exit_to_menu():
	if ai_is_thinking:
		chess_logic.stop_ai_thinking()
	get_tree().change_scene_to_file("uid://dwnbfraut6h7t")
