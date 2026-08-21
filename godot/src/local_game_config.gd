extends Control

signal config_finished(config_data: Dictionary[String, Variant])

const time_per_side_minute_values: PackedFloat64Array = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0,
	13.0, 14.0, 15.0, 16.0, 17.0,18.0, 19.0, 20.0, 25.0, 30.0, 35.0, 40.0, 45.0, 60.0, 75.0, 90.0, 105.0, 120.0, 135.0, 150.0, 165.0, 180.0, -1.0]
const time_increment_second_values: PackedInt64Array = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
	10, 11, 12, 13, 14, 15, 16,17, 18, 19, 20, 25, 30, 35, 40, 45, 60, 90, 120, 150, 180]

@onready var player_color_button: Button = $player_color_button
@onready var game_mode_button: Button = $game_mode_button
@onready var opponent_button: Button = $opponent_button
@onready var ai_config_control: Control = $ai_config_control
@onready var ai_skill_level_label: Label = $ai_config_control/ai_skill_level_label
@onready var time_per_side_bar: HScrollBar = $time_per_side_bar
@onready var time_per_side_label: Label = $time_per_side_bar/time_per_side_label
@onready var time_increment_bar: HScrollBar = $time_increment_bar
@onready var time_increment_label: Label = $time_increment_bar/time_increment_label

var config_data: Dictionary[String, Variant] = {
	"player_color": Enums.ChessColor.WHITE,
	"game_mode": Enums.GameMode.STANDARD,
	"connection_type": Enums.ConnectionType.LOCAL,
	"local_opponent": Enums.LocalOpponent.HUMAN,
	"time_per_side": -60_000,
	"time_increment": 0,
	"ai_binary_path": "",
	"ai_skill_level": 0}


func _on_player_color_button_pressed() -> void:
	match config_data["player_color"]:
		Enums.ChessColor.WHITE:
			config_data["player_color"] = Enums.ChessColor.BLACK
			player_color_button.text = "Player side: Black"
		Enums.ChessColor.BLACK:
			config_data["player_color"] = Enums.ChessColor.WHITE
			player_color_button.text = "Player side: White"


func _on_game_mode_button_pressed() -> void:
	match config_data["game_mode"]:
		Enums.GameMode.STANDARD:
			config_data["game_mode"] = Enums.GameMode.CHESS960
			game_mode_button.text = "Game mode: Chess960"
		Enums.GameMode.CHESS960:
			config_data["game_mode"] = Enums.GameMode.STANDARD
			game_mode_button.text = "Game mode: Standard"


func _on_opponent_button_pressed() -> void:
	match config_data["local_opponent"]:
		Enums.LocalOpponent.HUMAN:
			config_data["local_opponent"] = Enums.LocalOpponent.AI
			opponent_button.text = "Opponent: AI"
			ai_config_control.show()
		Enums.LocalOpponent.AI:
			config_data["local_opponent"] = Enums.LocalOpponent.HUMAN
			opponent_button.text = "Opponent: Human"
			ai_config_control.hide()


func _on_ai_skill_level_bar_value_changed(value: float) -> void:
	config_data["ai_skill_level"] = int(value)
	ai_skill_level_label.text = "AI skill level: " + str(int(value))


func _on_time_per_side_bar_value_changed(value: float) -> void:
	var index: int = int(value)
	var new_minute: float = time_per_side_minute_values[index]
	var new_time: int = int(new_minute * 60 * 1000)
	
	config_data["time_per_side"] = new_time
	
	if new_time == -60_000:
		time_per_side_label.text = "Minutes per side: Unlimited"
		time_increment_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		time_increment_bar.modulate.a = 0.5
		time_increment_label.modulate.a = 0.5
	else:
		if str(new_minute).split(".")[1] == "0":
			time_per_side_label.text = "Minutes per side: " + str(int(new_minute))
		else:
			time_per_side_label.text = "Minutes per side: " + str(new_minute)
		time_increment_bar.mouse_filter = Control.MOUSE_FILTER_STOP
		time_increment_bar.modulate.a = 1.0
		time_increment_label.modulate.a = 1.0


func _on_time_increment_bar_value_changed(value: float) -> void:
	config_data["time_increment"] = time_increment_second_values[int(value)] * 1000
	time_increment_label.text = "Increment in seconds " + str(time_increment_second_values[int(value)])


func _on_start_button_pressed() -> void:
	if config_data["local_opponent"] == Enums.LocalOpponent.AI:
		config_data["ai_binary_path"] = get_ai_binary_path()
	config_finished.emit(config_data)


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
