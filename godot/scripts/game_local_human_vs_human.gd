extends Control

@onready var chess_board_node: Control = $chess_board
@onready var promotion_selection_node: Control = $promotion_selection

var opponent: Enums.Opponent = Enums.Opponent.LOCAL_HUMAN
var game_mode: Enums.GameMode = Enums.GameMode.CHESS960
var player_color: Enums.ChessColor = Enums.ChessColor.WHITE


func _ready() -> void:
	chess_board_node.opponent = opponent
	chess_board_node.game_mode = game_mode
	chess_board_node.player_color = player_color
	chess_board_node.initialize_board()
	chess_board_node.move_animation_started.connect(_on_move_animation_started)
	chess_board_node.move_animation_finished.connect(_on_move_animation_finished)
	chess_board_node.promotion_selection_required.connect(_on_promotion_selection_required)
	chess_board_node.match_finished.connect(_on_match_finished)
	
	for selection_button: Button in promotion_selection_node.get_node("white").get_children() + promotion_selection_node.get_node("black").get_children():
		selection_button.button_up.connect(_on_promotion_selected.bind(selection_button.name))


func _on_move_animation_started(_move_type: String):
	pass


func _on_move_animation_finished(_move_type: String):
	pass


func _on_promotion_selection_required():
	match chess_board_node.chess_logic.get_turn():
		Enums.ChessColor.WHITE:
			promotion_selection_node.get_node("white").show()
			promotion_selection_node.get_node("black").hide()
		Enums.ChessColor.BLACK:
			promotion_selection_node.get_node("black").show()
			promotion_selection_node.get_node("white").hide()
	
	promotion_selection_node.show()


func _on_promotion_selected(selected_piece: String):
	chess_board_node.apply_promotion_move(selected_piece)
	promotion_selection_node.hide()


func _on_match_finished(winner: String):
	match winner:
		"draw":
			print("maç berabere bitti")
		"white":
			print("beyaz maçı kazandı")
		"black":
			print("siyah maçı kazandı")
