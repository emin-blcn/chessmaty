extends TabContainer

signal configure_finished(game_config_data: Dictionary)

const minute_per_side_values: PackedFloat64Array = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0, 20.0, 25.0, 30.0, 35.0, 40.0, 45.0, 60.0, 75.0, 90.0, 105.0, 120.0, 135.0, 150.0, 165.0, 180.0, 999.0]
const increment_second_values: PackedInt64Array = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 25, 30, 35, 40, 45, 60, 90, 120, 150, 180]

@onready var game_mode_button: Button = $local_game/game_mode_button
@onready var player_color_button: Button = $local_game/player_color_button
@onready var opponent_button: Button = $local_game/opponent_button
@onready var ai_config_control: Control = $local_game/ai_config_control
@onready var ai_skill_level_label: Label = $local_game/ai_config_control/ai_skill_level_label
@onready var minute_per_side_bar: HScrollBar = $local_game/minute_per_side_bar
@onready var minute_per_side_label: Label = $local_game/minute_per_side_bar/minute_per_side_label
@onready var increment_second_bar: HScrollBar = $local_game/increment_second_bar
@onready var increment_second_label: Label = $local_game/increment_second_bar/increment_second_label

var game_config_data: Dictionary = {
	"game_mode": Enums.GameMode.STANDARD,
	"player_color": Enums.ChessColor.WHITE,
	"opponent": Enums.Opponent.LOCAL_HUMAN,
	"ai_skill_level": 0,
	"minute_per_side": 999.0,
	"increment_second": 0}


func _on_game_mode_button_pressed() -> void:
	match game_config_data["game_mode"]:
		Enums.GameMode.STANDARD:
			game_config_data["game_mode"] = Enums.GameMode.CHESS960
			game_mode_button.text = "Game mode: Chess960"
		Enums.GameMode.CHESS960:
			game_config_data["game_mode"] = Enums.GameMode.STANDARD
			game_mode_button.text = "Game mode: Standard"


func _on_player_color_button_pressed() -> void:
	match game_config_data["player_color"]:
		Enums.ChessColor.WHITE:
			game_config_data["player_color"] = Enums.ChessColor.BLACK
			player_color_button.text = "Player side: Black"
		Enums.ChessColor.BLACK:
			game_config_data["player_color"] = Enums.ChessColor.WHITE
			player_color_button.text = "Player side: White"


func _on_opponent_button_pressed() -> void:
	match game_config_data["opponent"]:
		Enums.Opponent.LOCAL_HUMAN:
			game_config_data["opponent"] = Enums.Opponent.LOCAL_AI
			opponent_button.text = "Opponent: AI"
			ai_config_control.show()
		Enums.Opponent.LOCAL_AI:
			game_config_data["opponent"] = Enums.Opponent.LOCAL_HUMAN
			opponent_button.text = "Opponent: Human"
			ai_config_control.hide()


func _on_ai_skill_level_bar_value_changed(value: float) -> void:
	game_config_data["ai_skill_level"] = int(value)
	ai_skill_level_label.text = "AI skill level: " + str(int(value))


func _on_minute_per_side_bar_value_changed(value: float) -> void:
	var new_value: float = minute_per_side_values[int(value)]
	game_config_data["minute_per_side"] = new_value
	
	if is_equal_approx(new_value, 999.0):
		minute_per_side_label.text = "Minutes per side: Unlimited"
		
		increment_second_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		increment_second_label.modulate.a = 0.5
		increment_second_bar.modulate.a = 0.5
	else:
		if str(new_value).split(".")[1] == "0":
			minute_per_side_label.text = "Minutes per side: " + str(int(new_value))
		else:
			minute_per_side_label.text = "Minutes per side: " + str(new_value)
		
		increment_second_bar.mouse_filter = Control.MOUSE_FILTER_STOP
		increment_second_label.modulate.a = 1.0
		increment_second_bar.modulate.a = 1.0


func _on_increment_second_bar_value_changed(value: float) -> void:
	game_config_data["increment_second"] = increment_second_values[int(value)]
	increment_second_label.text = "Increment in seconds " + str(increment_second_values[int(value)])


func _on_start_button_pressed() -> void:
	configure_finished.emit(game_config_data)


func _on_tab_changed(tab: int) -> void:
	match tab:
		0:
			print("local game tab")
		1:
			print("LAN game tab")
