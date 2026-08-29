extends Control

@onready var master_scene: Control = get_tree().current_scene
@onready var top_check_message_label: Label = $top_check_message_label
@onready var top_check_label: Label = $top_check_message_label/check_label
@onready var bottom_check_message_label: Label = $bottom_check_message_label
@onready var bottom_check_label: Label = $bottom_check_message_label/check_label

var config_data: Dictionary[String, Variant] = {}


func config(new_config_data: Dictionary[String, Variant]):
	config_data["player_color"] = new_config_data["player_color"]
	
	# remove this object if game mode is not three check
	if new_config_data["game_mode"] != Enums.GameMode.THREE_CHECK:
		queue_free()
	else:
		# reverse gui elements if player side is black (default gui order is white)
		if config_data["player_color"] == Enums.ChessColor.BLACK:
			top_check_message_label.text = "White checks:"
			top_check_message_label.add_theme_color_override("font_color", Color("a6bac4ff"))
			top_check_message_label.text = "Black checks:"
			top_check_message_label.add_theme_color_override("font_color", Color("70334cff"))
		show()


func _on_move_animation_finished(move_type: Enums.MoveType):
	if move_type == Enums.MoveType.PROMOTION:
		return
	elif move_type == Enums.MoveType.UNDO:
		update_white_check_label()
		update_black_check_label()
	else: # update opposite color's label
		match master_scene.get_turn():
			Enums.ChessColor.WHITE:
				update_black_check_label()
			Enums.ChessColor.BLACK:
				update_white_check_label()


func update_white_check_label():
	var white_check_label: Label = bottom_check_label if config_data["player_color"] == Enums.ChessColor.WHITE else top_check_label
	white_check_label.text = str(master_scene.get_white_checks()) + "/3"


func update_black_check_label():
	var black_check_label: Label = top_check_label if config_data["player_color"] == Enums.ChessColor.WHITE else bottom_check_label
	black_check_label.text = str(master_scene.get_black_checks()) + "/3"
