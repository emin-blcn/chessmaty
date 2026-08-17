extends TextureRect

signal promotion_selected(selected_piece: Enums.Piece)

@onready var master_scene: Control = get_tree().current_scene

var config_data: Dictionary = {
	"player_color": Enums.ChessColor.WHITE,
	"opponent": Enums.Opponent.LOCAL_HUMAN}


func config(player_color: Enums.ChessColor, opponent: Enums.Opponent) -> void:
	config_data["player_color"] = player_color
	config_data["opponent"] = opponent
	
	if opponent == Enums.Opponent.LOCAL_HUMAN:
		for button: Button in get_node("Panel/white").get_children() + get_node("Panel/black").get_children():
			button.pressed.connect(_on_selection_button_pressed.bind(button.name))
	else:
		match player_color:
			Enums.ChessColor.WHITE:
				get_node("Panel/black").queue_free()
				for button: Button in get_node("Panel/white").get_children():
					button.pressed.connect(_on_selection_button_pressed.bind(button.name))
			Enums.ChessColor.BLACK:
				get_node("Panel/white").queue_free()
				for button: Button in get_node("Panel/black").get_children():
					button.pressed.connect(_on_selection_button_pressed.bind(button.name))


func _on_promotion_selection_required():
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
	promotion_selected.emit(int(button_name) as Enums.Piece)
	hide()
