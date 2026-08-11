extends Control

@onready var game_config_control_node: Panel = $game_config
@onready var game_mode_button_node: Button = $game_config/game_mode_button
@onready var player_color_button_node: Button = $game_config/player_color_button
@onready var opponent_button_node: Button = $game_config/opponent_button
@onready var ai_config_node: Control = $game_config/ai_config
@onready var ai_skill_level_label_node: Label = $game_config/ai_config/ai_skill_level_label
@onready var ai_skill_level_bar_node: HScrollBar = $game_config/ai_config/ai_skill_level_bar
@onready var minute_per_side_label_node: Label = $game_config/minute_per_side_label
@onready var minute_per_side_bar_node: HScrollBar = $game_config/minute_per_side_bar
@onready var increment_second_label_node: Label = $game_config/increment_second_label
@onready var increment_second_bar_node: HScrollBar = $game_config/increment_second_bar

@onready var game_content_control_node: Control = $game_content
@onready var chess_board_node: Control = $game_content/chess_board
@onready var promotion_selection_node: Control = $game_content/promotion_selection
@onready var move_history_table_node: Panel = $game_content/move_history_table
@onready var undo_button_node: Button = $game_content/undo_button
@onready var undo_message_label_node: Label = $game_content/undo_message_label
@onready var leave_button_node: Button = $game_content/leave_button
@onready var leave_message_label_node: Label = $game_content/leave_message_label
@onready var top_time_message_label_node: Label = $game_content/top_time_message_label
@onready var top_time_left_label_node: Label = $game_content/top_time_message_label/top_time_left_label
@onready var bottom_time_message_label_node: Label = $game_content/bottom_time_message_label
@onready var bottom_time_left_label_node: Label = $game_content/bottom_time_message_label/bottom_time_left_label

@onready var second_timer: Timer = $second_timer

var opponent: Enums.Opponent = Enums.Opponent.LOCAL_HUMAN
var game_mode: Enums.GameMode = Enums.GameMode.STANDARD
var player_color: Enums.ChessColor = Enums.ChessColor.WHITE
var chess_engine: Enums.ChessEngine = Enums.ChessEngine.STOCKFISH
var ai_skill_level: int = 0
var minute_per_side: int = 181
var increment_second: int = 0
var white_time_left_second: int = 0
var black_time_left_second: int = 0
var time_left_seconds_in_moves: Array[Vector2i]


func _ready() -> void:
	chess_board_node.move_animation_started.connect(_on_move_animation_started)
	chess_board_node.move_animation_finished.connect(_on_move_animation_finished)
	chess_board_node.promotion_selection_required.connect(_on_promotion_selection_required)
	chess_board_node.match_finished.connect(_on_match_finished)


func initialize_board():
	if minute_per_side == 181:
		second_timer.queue_free()
	else:
		white_time_left_second = minute_per_side * 60
		black_time_left_second = minute_per_side * 60
		update_white_time_left_text()
		update_black_time_left_text()
		if player_color == Enums.ChessColor.BLACK:
			top_time_message_label_node.text = "White time left:"
			top_time_message_label_node.add_theme_color_override("font_color", Color("a6bac4ff"))
			bottom_time_message_label_node.text = "Black time left:"
			bottom_time_message_label_node.add_theme_color_override("font_color", Color("70334cff"))
		top_time_message_label_node.show()
		bottom_time_message_label_node.show()
	
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
	
	chess_board_node.opponent = opponent
	chess_board_node.game_mode = game_mode
	chess_board_node.player_color = player_color
	chess_board_node.minute_per_side = minute_per_side
	chess_board_node.increment_second = increment_second
	chess_board_node.white_time_left_second = white_time_left_second
	chess_board_node.black_time_left_second = black_time_left_second
	if opponent == Enums.Opponent.LOCAL_AI:
		chess_board_node.ai_binary_path = get_ai_binary_path()
		chess_board_node.ai_skill_level = ai_skill_level
	chess_board_node.initialize_board()
	game_content_control_node.show()
	game_config_control_node.queue_free()


func set_times(white_new_time: int, black_new_time: int) -> void:
	white_time_left_second = white_new_time
	black_time_left_second = black_new_time
	
	chess_board_node.white_time_left_second = white_new_time
	chess_board_node.black_time_left_second = black_new_time
	
	update_white_time_left_text()
	update_black_time_left_text()


func _on_move_animation_started(move_type: Enums.MoveType, from: String, to: String):
	if move_type == Enums.MoveType.UNDO:
		move_history_table_node.remove_element(chess_board_node.chess_logic.get_turn())
	else:
		var moved_color = Enums.ChessColor.WHITE if chess_board_node.chess_logic.get_turn() == Enums.ChessColor.BLACK else Enums.ChessColor.BLACK
		move_history_table_node.add_element(moved_color, from, to)
	
	if minute_per_side == 181:
		return
	
	second_timer.stop()
	
	if move_type == Enums.MoveType.UNDO:
		if not time_left_seconds_in_moves.is_empty():
			var previous_times: Vector2i = time_left_seconds_in_moves.pop_back()
			set_times(previous_times.x, previous_times.y)
		else:
			var full_time = minute_per_side * 60
			set_times(full_time, full_time)
	else:
		var white_new_time = white_time_left_second
		var black_new_time = black_time_left_second
		
		time_left_seconds_in_moves.append(Vector2i(white_new_time, black_new_time))
		
		# Lichess kuralı: 2. hamleden itibaren hamle başı ek süreyi ekle
		if time_left_seconds_in_moves.size() >= 2:
			var moved_color = Enums.ChessColor.WHITE if chess_board_node.chess_logic.get_turn() == Enums.ChessColor.BLACK else Enums.ChessColor.BLACK
			if moved_color == Enums.ChessColor.WHITE:
				white_new_time += increment_second
			else:
				black_new_time += increment_second
				
		set_times(white_new_time, black_new_time)


func _on_move_animation_finished(move_type: Enums.MoveType):
	if minute_per_side != 181:
		# Lichess standardı: İlk 2 hamle tamamlandıktan sonra saat geri saymaya başlar
		if time_left_seconds_in_moves.size() >= 2:
			second_timer.start(1.0)
	
	if move_type == Enums.MoveType.NORMAL:
		Sounds.move_sfx.play()


func _on_second_timer_timeout() -> void:
	match chess_board_node.current_turn:
		Enums.ChessColor.WHITE:
			set_times(white_time_left_second - 1, black_time_left_second)
			if white_time_left_second <= 0:
				chess_board_node.input_control_node.hide()
				_on_match_finished(Enums.MatchFinishedState.BLACK_WON)
				
		Enums.ChessColor.BLACK:
			set_times(white_time_left_second, black_time_left_second - 1)
			if black_time_left_second <= 0:
				chess_board_node.input_control_node.hide()
				_on_match_finished(Enums.MatchFinishedState.WHITE_WON)


func update_white_time_left_text():
	var label_node: Label = bottom_time_left_label_node if player_color == Enums.ChessColor.WHITE else top_time_left_label_node
	var hour = white_time_left_second / 3600
	var min = (white_time_left_second % 3600) / 60
	var sec = white_time_left_second % 60
	
	if minute_per_side >= 60:
		label_node.text = "%02d:%02d:%02d" % [hour, min, sec]
	else:
		label_node.text = "%02d:%02d" % [min, sec]


func update_black_time_left_text():
	var label_node: Label = bottom_time_left_label_node if player_color == Enums.ChessColor.BLACK else top_time_left_label_node
	var hour = black_time_left_second / 3600
	var min = (black_time_left_second % 3600) / 60
	var sec = black_time_left_second % 60
	
	if minute_per_side >= 60:
		label_node.text = "%02d:%02d:%02d" % [hour, min, sec]
	else:
		label_node.text = "%02d:%02d" % [min, sec]


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
	undo_message_label_node.show()


func _on_undo_button_mouse_exited() -> void:
	undo_message_label_node.hide()


func _on_leave_button_pressed() -> void:
	if leave_message_label_node.text == "Leave match":
		leave_message_label_node.text = "Click again"
	else:
		get_tree().change_scene_to_packed( load("uid://dwnbfraut6h7t") )


func _on_leave_button_mouse_entered() -> void:
	leave_message_label_node.show()


func _on_leave_button_mouse_exited() -> void:
	leave_message_label_node.hide()
	if leave_message_label_node.text == "Click again":
		leave_message_label_node.text = "Leave match"


func _on_game_mode_button_pressed() -> void:
	match game_mode:
		Enums.GameMode.STANDARD:
			game_mode = Enums.GameMode.CHESS960
			game_mode_button_node.text = "Game mode: Chess960"
		Enums.GameMode.CHESS960:
			game_mode = Enums.GameMode.STANDARD
			game_mode_button_node.text = "Game mode: Standard"


func _on_opponent_button_pressed() -> void:
	match opponent:
		Enums.Opponent.LOCAL_HUMAN:
			opponent = Enums.Opponent.LOCAL_AI
			opponent_button_node.text = "Opponent: AI"
			ai_config_node.show()
		Enums.Opponent.LOCAL_AI:
			opponent = Enums.Opponent.LOCAL_HUMAN
			opponent_button_node.text = "Opponent: Human"
			ai_config_node.hide()

func _on_ai_skill_level_bar_value_changed(value: float) -> void:
	ai_skill_level = int(value)
	ai_skill_level_label_node.text = "AI skill level: " + str(ai_skill_level)


func _on_player_color_button_pressed() -> void:
	match player_color:
		Enums.ChessColor.WHITE:
			player_color = Enums.ChessColor.BLACK
			player_color_button_node.text = "Player side: Black"
		Enums.ChessColor.BLACK:
			player_color = Enums.ChessColor.WHITE
			player_color_button_node.text = "Player side: White"

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
	second_timer.stop()
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


func _on_minute_per_side_bar_value_changed(value: float) -> void:
	minute_per_side = int(value)
	if minute_per_side == 181:
		minute_per_side_label_node.text = "Minutes per side: Unlimited"
		increment_second_bar_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		increment_second = 0
		increment_second_label_node.modulate.a = 0.5
		increment_second_bar_node.modulate.a = 0.5
	else:
		minute_per_side_label_node.text = "Minutes per side: " + str(minute_per_side)
		increment_second_bar_node.mouse_filter = Control.MOUSE_FILTER_STOP
		increment_second_label_node.modulate.a = 1.0
		increment_second_bar_node.modulate.a = 1.0


func _on_increment_second_bar_value_changed(value: float) -> void:
	increment_second = int(value)
	increment_second_label_node.text = "Increment in seconds " + str(increment_second)
