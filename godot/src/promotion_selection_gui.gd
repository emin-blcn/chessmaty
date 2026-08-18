extends TextureRect

@onready var master_scene: Control = get_tree().current_scene

var config_data: Dictionary


func config(new_config_data: Dictionary) -> void:
	config_data = new_config_data
	
	if config_data["opponent"] == Enums.Opponent.LOCAL_HUMAN:
		for button: Button in get_node("Panel/white").get_children() + get_node("Panel/black").get_children():
			button.pressed.connect(_on_selection_button_pressed.bind(button.name))
	else:
		match config_data["player_color"]:
			Enums.ChessColor.WHITE:
				get_node("Panel/black").queue_free()
				for button: Button in get_node("Panel/white").get_children():
					button.pressed.connect(_on_selection_button_pressed.bind(button.name))
			Enums.ChessColor.BLACK:
				get_node("Panel/white").queue_free()
				for button: Button in get_node("Panel/black").get_children():
					button.pressed.connect(_on_selection_button_pressed.bind(button.name))


func _on_move_animation_finished(move_type: Enums.MoveType):
	if move_type == Enums.MoveType.PROMOTION_REQUEST_BY_HUMAN:
		if config_data["opponent"] == Enums.Opponent.LOCAL_HUMAN:
			match master_scene.get_turn():
				Enums.ChessColor.WHITE:
					get_node("Panel/white").show()
					get_node("Panel/black").hide()
				Enums.ChessColor.BLACK:
					get_node("Panel/black").show()
					get_node("Panel/white").hide()
		show()


func _on_selection_button_pressed(button_name: StringName):
	master_scene.apply_promotion_move(int(button_name) as Enums.Piece)
	hide()
