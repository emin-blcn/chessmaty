extends Control

signal config_finished(config_data: Dictionary[String, Variant])

const time_per_side_minute_values: PackedFloat64Array = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0,
	13.0, 14.0, 15.0, 16.0, 17.0,18.0, 19.0, 20.0, 25.0, 30.0, 35.0, 40.0, 45.0, 60.0, 75.0, 90.0, 105.0, 120.0, 135.0, 150.0, 165.0, 180.0, -1.0]
const time_increment_second_values: PackedInt64Array = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
	10, 11, 12, 13, 14, 15, 16,17, 18, 19, 20, 25, 30, 35, 40, 45, 60, 90, 120, 150, 180]

@onready var player_color_button: Button = $player_color_button
@onready var game_mode_button: Button = $game_mode_button
@onready var game_mode_color_rect: ColorRect = $game_mode_color_rect
@onready var time_per_side_label: Label = $time_per_side_slider/time_per_side_label
@onready var time_increment_slider: HSlider = $time_increment_slider
@onready var time_increment_label: Label = $time_increment_slider/time_increment_label
@onready var opponent_button: Button = $opponent_button
@onready var ai_skill_level_slider: HSlider = $ai_skill_level_slider
@onready var ai_skill_level_label: Label = $ai_skill_level_slider/ai_skill_level_label

var config_data: Dictionary[String, Variant] = {
	"player_color": Enums.ChessColor.WHITE,
	"game_mode": Enums.GameMode.STANDARD,
	"fen_string": "",
	"connection_type": Enums.ConnectionType.LOCAL,
	"local_opponent": Enums.LocalOpponent.HUMAN,
	"time_per_side": -60_000,
	"time_increment": 0,
	"ai_skill_level": 0}


func _ready() -> void:
	$game_mode_color_rect/game_mode_item_list.select(0)


func _on_player_color_button_pressed() -> void:
	Sound.button_tick.play()
	match config_data["player_color"]:
		Enums.ChessColor.WHITE:
			config_data["player_color"] = Enums.ChessColor.BLACK
			player_color_button.text = "Player side: Black"
		Enums.ChessColor.BLACK:
			config_data["player_color"] = Enums.ChessColor.WHITE
			player_color_button.text = "Player side: White"


func _on_game_mode_button_pressed() -> void:
	Sound.button_tick.play()
	game_mode_color_rect.show()


func _on_game_mode_item_list_item_clicked(index: int, _at_position: Vector2, mouse_button_index: int) -> void:
	Sound.button_tick.play()
	if mouse_button_index != MouseButton.MOUSE_BUTTON_LEFT:
		return
	
	var selected_mode: Enums.GameMode = index as Enums.GameMode
	config_data["game_mode"] = selected_mode
	match selected_mode:
		Enums.GameMode.STANDARD: game_mode_button.text = "Game mode: Standard"
		Enums.GameMode.CHESS960: game_mode_button.text = "Game mode: Chess960"
		Enums.GameMode.KING_OF_THE_HILL: game_mode_button.text = "Game mode: King Of The Hill"
		Enums.GameMode.THREE_CHECK: game_mode_button.text = "Game mode: Three-Check"
		Enums.GameMode.CRAZY_HOUSE: game_mode_button.text = "Game mode: Crazyhouse"
		Enums.GameMode.ANTI_CHESS: game_mode_button.text = "Game mode: Antichess"
		Enums.GameMode.ATOMIC: game_mode_button.text = "Game mode: Atomic"
		Enums.GameMode.HORDE: game_mode_button.text = "Game mode: Horde"
		Enums.GameMode.RACING_KINGS: game_mode_button.text = "Game mode: Racing Kings"
	game_mode_color_rect.hide()


func _on_opponent_button_pressed() -> void:
	Sound.button_tick.play()
	match config_data["local_opponent"]:
		Enums.LocalOpponent.HUMAN:
			config_data["local_opponent"] = Enums.LocalOpponent.AI
			opponent_button.text = "Opponent: AI"
			ai_skill_level_slider.show()
		Enums.LocalOpponent.AI:
			config_data["local_opponent"] = Enums.LocalOpponent.HUMAN
			opponent_button.text = "Opponent: Human"
			ai_skill_level_slider.hide()


func _on_ai_skill_level_slider_value_changed(value: float) -> void:
	config_data["ai_skill_level"] = int(value)
	ai_skill_level_label.text = "AI skill level: " + str(int(value))


func _on_time_per_side_slider_value_changed(value: float) -> void:
	var index: int = int(value)
	var new_minute: float = time_per_side_minute_values[index]
	var new_time: int = int(new_minute * 60 * 1000)
	
	config_data["time_per_side"] = new_time
	
	if new_time == -60_000:
		time_per_side_label.text = "Minutes per side: Unlimited"
		time_increment_slider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		time_increment_slider.modulate.a = 0.5
		time_increment_label.modulate.a = 0.5
	else:
		if str(new_minute).split(".")[1] == "0":
			time_per_side_label.text = "Minutes per side: " + str(int(new_minute))
		else:
			time_per_side_label.text = "Minutes per side: " + str(new_minute)
		time_increment_slider.mouse_filter = Control.MOUSE_FILTER_STOP
		time_increment_slider.modulate.a = 1.0
		time_increment_label.modulate.a = 1.0


func _on_time_increment_slider_value_changed(value: float) -> void:
	config_data["time_increment"] = time_increment_second_values[int(value)] * 1000
	time_increment_label.text = "Increment in seconds: " + str(time_increment_second_values[int(value)])


func _on_start_button_pressed() -> void:
	Sound.button_tick.play()
	if config_data["game_mode"] == Enums.GameMode.CHESS960:
		config_data["fen_string"] = ChessLogic.random_fen()
	
	config_finished.emit(config_data)


func _on_back_button_pressed() -> void:
	Sound.button_tick.play()
	get_tree().change_scene_to_file("uid://dwnbfraut6h7t")
