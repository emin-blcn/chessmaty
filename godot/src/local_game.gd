extends Control

@onready var game_config: Panel = $game_config
@onready var game_mode_button: Button = $game_config/game_mode_button
@onready var player_color_button: Button = $game_config/player_color_button
@onready var opponent_button: Button = $game_config/opponent_button
@onready var ai_config: Control = $game_config/ai_config
@onready var skill_level_button: Button = $game_config/ai_config/skill_level_button

@onready var game_content: Control = $game_content
@onready var chess_board_node: Control = $game_content/chess_board
@onready var promotion_selection_node: Control = $game_content/promotion_selection
@onready var move_history_table_node: Panel = $game_content/move_history_table
@onready var undo_button: Button = $game_content/undo_button
@onready var undo_message_label: Label = $game_content/undo_message_label
@onready var leave_button: Button = $game_content/leave_button
@onready var leave_message_label: Label = $game_content/leave_message_label

var opponent: Enums.Opponent = Enums.Opponent.LOCAL_HUMAN
var game_mode: Enums.GameMode = Enums.GameMode.STANDARD
var player_color: Enums.ChessColor = Enums.ChessColor.WHITE
var chess_engine: Enums.ChessEngine = Enums.ChessEngine.STOCKFISH
var ai_skill_level: int = 20


func _ready() -> void:
	chess_board_node.move_animation_started.connect(_on_move_animation_started)
	chess_board_node.move_animation_finished.connect(_on_move_animation_finished)
	chess_board_node.promotion_selection_required.connect(_on_promotion_selection_required)
	chess_board_node.match_finished.connect(_on_match_finished)


func initialize_board():
	if opponent == Enums.Opponent.LOCAL_AI:
		chess_board_node.ai_binary_path = get_ai_binary_path()
	chess_board_node.opponent = opponent
	chess_board_node.game_mode = game_mode
	chess_board_node.player_color = player_color
	chess_board_node.ai_skill_level = ai_skill_level
	chess_board_node.initialize_board()
	game_config.hide()
	game_content.show()
	
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


func _on_move_animation_finished(move_type: Enums.MoveType):
	match move_type:
		Enums.MoveType.NORMAL:
			Sounds.move_sfx.play()


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


func _on_start_button_pressed() -> void:
	initialize_board()


func _on_undo_button_pressed() -> void:
	chess_board_node.undo_last_move()


func _on_undo_button_mouse_entered() -> void:
	undo_message_label.show()


func _on_undo_button_mouse_exited() -> void:
	undo_message_label.hide()


func _on_leave_button_pressed() -> void:
	if leave_message_label.text == "Leave match":
		leave_message_label.text = "Click again"
	else:
		get_tree().change_scene_to_packed( load("uid://dwnbfraut6h7t") )


func _on_leave_button_mouse_entered() -> void:
	leave_message_label.show()


func _on_leave_button_mouse_exited() -> void:
	leave_message_label.hide()
	if leave_message_label.text == "Click again":
		leave_message_label.text = "Leave match"


func _on_game_mode_button_pressed() -> void:
	match game_mode:
		Enums.GameMode.STANDARD:
			game_mode = Enums.GameMode.CHESS960
			game_mode_button.text = "Game mode: Chess960"
		Enums.GameMode.CHESS960:
			game_mode = Enums.GameMode.STANDARD
			game_mode_button.text = "Game mode: Standard"


func _on_opponent_button_pressed() -> void:
	match opponent:
		Enums.Opponent.LOCAL_HUMAN:
			opponent = Enums.Opponent.LOCAL_AI
			opponent_button.text = "Opponent: AI"
			ai_config.show()
		Enums.Opponent.LOCAL_AI:
			opponent = Enums.Opponent.LOCAL_HUMAN
			opponent_button.text = "Opponent: Human"
			ai_config.hide()


func _on_skill_level_button_pressed() -> void:
	if ai_skill_level >= 20:
		ai_skill_level = 0
	else:
		ai_skill_level += 1
	
	skill_level_button.text = "AI Skill Level: " + str(ai_skill_level)


func _on_player_color_button_pressed() -> void:
	match player_color:
		Enums.ChessColor.WHITE:
			player_color = Enums.ChessColor.BLACK
			player_color_button.text = "Player side: Black"
		Enums.ChessColor.BLACK:
			player_color = Enums.ChessColor.WHITE
			player_color_button.text = "Player side: White"

func get_ai_binary_path() -> String:
	var path: String
	if OS.has_feature("editor"):
		path = ProjectSettings.globalize_path("res://").get_base_dir().get_base_dir().path_join("bin")
	else:
		path = OS.get_executable_path().get_base_dir()
	
	var file_name: String
	match [chess_engine, OS.get_name()]:
		[Enums.ChessEngine.STOCKFISH, "Linux"]: file_name = "stockfish_linux_x86_64_avx2"
		[Enums.ChessEngine.STOCKFISH, "Windows"]: file_name = "stockfish_windows_x86_64_avx2.exe"
	
	return path.path_join(file_name)


func _on_match_finished(finished_state: Enums.MatchFinishedState):
	match finished_state:
		Enums.MatchFinishedState.FINISHED_DRAW:
			Sounds.draw_sfx.play()
			print("maç berabere bitti")
		Enums.MatchFinishedState.WHITE_WON:
			if player_color == Enums.ChessColor.WHITE:
				Sounds.victory_sfx.play()
			else:
				Sounds.defeat_sfx.play()
			print("beyaz maçı kazandı")
		Enums.MatchFinishedState.BLACK_WON:
			if player_color == Enums.ChessColor.BLACK:
				Sounds.victory_sfx.play()
			else:
				Sounds.defeat_sfx.play()
			print("siyah maçı kazandı")
