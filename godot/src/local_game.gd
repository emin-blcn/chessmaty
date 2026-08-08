extends Control

@onready var chess_board_node: Control = $chess_board
@onready var promotion_selection_node: Control = $promotion_selection
@onready var move_history_table_node: ColorRect = $move_history_table

var opponent: Enums.Opponent = Enums.Opponent.LOCAL_HUMAN
var game_mode: Enums.GameMode = Enums.GameMode.STANDARD
var player_color: Enums.ChessColor = Enums.ChessColor.WHITE


func _ready() -> void:
	chess_board_node.move_animation_started.connect(_on_move_animation_started)
	chess_board_node.move_animation_finished.connect(_on_move_animation_finished)
	chess_board_node.promotion_selection_required.connect(_on_promotion_selection_required)
	chess_board_node.match_finished.connect(_on_match_finished)
	initialize_board()


func initialize_board():
	chess_board_node.opponent = opponent
	chess_board_node.game_mode = game_mode
	chess_board_node.player_color = player_color
	chess_board_node.initialize_board()
	chess_board_node.show()
	
	if opponent == Enums.Opponent.LOCAL_HUMAN:
		for selection_button: Button in promotion_selection_node.get_node("white").get_children() + promotion_selection_node.get_node("black").get_children():
			selection_button.button_up.connect(_on_promotion_selected.bind( int(selection_button.name) as Enums.Piece ))
	else:
		match player_color:
			Enums.ChessColor.WHITE:
				promotion_selection_node.get_node("black").queue_free()
				
				for selection_button: Button in promotion_selection_node.get_node("white").get_children():
					selection_button.button_up.connect(_on_promotion_selected.bind( int(selection_button.name) as Enums.Piece ))
			
			Enums.ChessColor.BLACK:
				promotion_selection_node.get_node("white").queue_free()
				
				for selection_button: Button in promotion_selection_node.get_node("black").get_children():
					selection_button.button_up.connect(_on_promotion_selected.bind( int(selection_button.name) as Enums.Piece ))


func _on_move_animation_started(move_type: Enums.MoveType, from: String, to: String):
	var moved_color: Enums.ChessColor
	
	if move_type == Enums.MoveType.UNDO:
		moved_color = chess_board_node.chess_logic.get_turn() as Enums.ChessColor
		move_history_table_node.remove_element(moved_color)
	else:
		moved_color = Enums.ChessColor.WHITE if chess_board_node.chess_logic.get_turn() == Enums.ChessColor.BLACK else Enums.ChessColor.BLACK
		move_history_table_node.add_element(moved_color, from, to)


func _on_move_animation_finished(_move_type: Enums.MoveType):
	pass


func _on_promotion_selection_required():
	if opponent == Enums.Opponent.LOCAL_HUMAN:
		match chess_board_node.chess_logic.get_turn():
			Enums.ChessColor.WHITE:
				promotion_selection_node.get_node("white").show()
				promotion_selection_node.get_node("black").hide()
			Enums.ChessColor.BLACK:
				promotion_selection_node.get_node("black").show()
				promotion_selection_node.get_node("white").hide()
	
	promotion_selection_node.show()


func _on_promotion_selected(selected_piece: Enums.Piece):
	chess_board_node.apply_promotion_move(selected_piece)
	promotion_selection_node.hide()


func _on_match_finished(finished_state: Enums.MatchFinishedState):
	match finished_state:
		Enums.MatchFinishedState.FINISHED_DRAW:
			print("maç berabere bitti")
		Enums.MatchFinishedState.WHITE_WON:
			print("beyaz maçı kazandı")
		Enums.MatchFinishedState.BLACK_WON:
			print("siyah maçı kazandı")
