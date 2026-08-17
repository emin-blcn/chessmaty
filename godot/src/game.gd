extends Control

@onready var game_content_node: Control = $game_content
@onready var game_config_gui_node: TabContainer = $game_config_gui

@onready var chess_board_node: Control = $game_content/chess_board
@onready var move_history_table_node: Panel = $game_content/hud/move_history_table
@onready var promotion_selection_node: TextureRect = $game_content/hud/promotion_selection
@onready var match_finished_node: Control = $game_content/hud/match_finished
@onready var time_control_node: Control = $game_content/hud/time_control


var chess_logic: ChessLogic = ChessLogic.new()
var game_config_data: Dictionary = {
	"game_mode": Enums.GameMode.STANDARD,
	"player_color": Enums.ChessColor.WHITE,
	"opponent": Enums.Opponent.LOCAL_HUMAN,
	"ai_skill_level": 0,
	"minute_per_side": 999.0,
	"increment_second": 0}


func _ready() -> void:
	game_config_gui_node.configure_finished.connect(_on_game_config_finished)


func _on_game_config_finished(new_game_config_data: Dictionary):
	game_config_data = new_game_config_data
	promotion_selection_node.config(new_game_config_data["player_color"], new_game_config_data["opponent"])
	time_control_node.config(new_game_config_data["player_color"], new_game_config_data["opponent"], new_game_config_data["minute_per_side"], new_game_config_data["increment_second"])
	
	game_content_node.show()
	game_config_gui_node.queue_free()


func _on_move_animation_started(move_type: Enums.MoveType, from: String, to: String):
	if move_type == Enums.MoveType.UNDO:
		if match_finished_node.visible:
			match_finished_node.hide()
	else:
		var moved_color = Enums.ChessColor.WHITE if get_turn() == Enums.ChessColor.BLACK else Enums.ChessColor.BLACK
		move_history_table_node.add_element(moved_color, from, to)


func _on_move_animation_finished(move_type: Enums.MoveType):
	if move_type == Enums.MoveType.NORMAL:
		Sounds.move_sfx.play()


func get_turn() -> Enums.ChessColor:
	return chess_logic.get_turn() as Enums.ChessColor


func _on_rematch_button_pressed() -> void:
	get_tree().reload_current_scene()





func _on_match_finished(finished_state: Enums.MatchFinishedState):
	chess_board_node.input_control_node.hide()
	
	match finished_state:
		Enums.MatchFinishedState.FINISHED_DRAW:
			Sounds.draw_sfx.play()
			match_finished_node.get_node("Label").text = "Game Drawn"
		Enums.MatchFinishedState.WHITE_WON:
			if game_config_data["player_color"] == Enums.ChessColor.WHITE:
				Sounds.victory_sfx.play()
			else:
				Sounds.defeat_sfx.play()
			match_finished_node.get_node("Label").text = "White Wins"
		Enums.MatchFinishedState.BLACK_WON:
			if game_config_data["player_color"] == Enums.ChessColor.BLACK:
				Sounds.victory_sfx.play()
			else:
				Sounds.defeat_sfx.play()
			match_finished_node.get_node("Label").text = "Black Wins"
	match_finished_node.show()


func get_ai_binary_path() -> String:
	var path: String
	if OS.has_feature("editor"):
		path = ProjectSettings.globalize_path("res://").get_base_dir().get_base_dir().path_join("bin")
	else:
		path = OS.get_executable_path().get_base_dir()
	
	var file_name: String
	match OS.get_name():
		"Linux": file_name = "stockfish_linux_x86_64_avx2"
		"Windows": file_name = "stockfish_windows_x86_64_avx2.exe"
	
	return path.path_join(file_name)
