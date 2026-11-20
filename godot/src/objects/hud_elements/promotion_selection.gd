extends TextureRect

var connection_type: Enums.ConnectionType
var local_opponent: Enums.LocalOpponent

@onready var master_scene: Control = get_tree().current_scene


func setup(data: Dictionary[String, Variant]) -> void:
	connection_type = data.get("connection_type")
	if connection_type == Enums.ConnectionType.LOCAL:
		local_opponent = data.get("local_opponent")

	if data.get("game_mode") != Enums.GameMode.ANTICHESS:
		var black_king_button: Button = $"Panel/black/0"
		var white_king_button: Button = $"Panel/white/0"
		$"Panel/black".remove_child(black_king_button)
		$"Panel/white".remove_child(white_king_button)
		white_king_button.queue_free()
		black_king_button.queue_free()


	if connection_type == Enums.ConnectionType.LOCAL and local_opponent == Enums.LocalOpponent.HUMAN:
		for button: Button in $Panel/white.get_children() + $Panel/black.get_children():
			button.pressed.connect(_on_selection_button_pressed.bind(button.name))
	else:
		match data.get("player_color"):
			Enums.ChessColor.WHITE:
				$Panel/black.queue_free()
				for button: Button in $Panel/white.get_children():
					button.pressed.connect(_on_selection_button_pressed.bind(button.name))
			Enums.ChessColor.BLACK:
				$Panel/white.queue_free()
				for button: Button in $Panel/black.get_children():
					button.pressed.connect(_on_selection_button_pressed.bind(button.name))


func show_promotion_selection() -> void:
	if connection_type == Enums.ConnectionType.LOCAL and local_opponent == Enums.LocalOpponent.HUMAN:
		match master_scene.get_active_turn():
			Enums.ChessColor.WHITE:
				$Panel/white.show()
				$Panel/black.hide()
			Enums.ChessColor.BLACK:
				$Panel/black.show()
				$Panel/white.hide()
	show()


func _on_selection_button_pressed(button_name: StringName) -> void:
	Sound.button_tick.play()

	var role: Enums.PieceRole
	match button_name:
		&"0": role = Enums.PieceRole.KING # only antichess mode
		&"1": role = Enums.PieceRole.QUEEN
		&"2": role = Enums.PieceRole.BISHOP
		&"3": role = Enums.PieceRole.KNIGHT
		&"4": role = Enums.PieceRole.ROOK

	master_scene.update_promotion_move_role_data(role)
	master_scene.apply_promotion_move()
	hide()
