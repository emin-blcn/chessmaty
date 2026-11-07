extends Control

signal piece_selected_for_put_move(piece_role: Enums.PieceRole)
signal piece_unselected_for_put_move

var player_color: Enums.ChessColor
var connection_type: Enums.ConnectionType
var local_opponent: Enums.LocalOpponent
var selected_button: Button

@onready var master_scene: Control = get_tree().current_scene
@onready var selected_piece_marker_node: Panel = $selected_piece_marker
@onready var white_elements_node: GridContainer = $white
@onready var black_elements_node: GridContainer = $black



func config(new_config_data: Dictionary[String, Variant]) -> void:
	player_color = new_config_data["player_color"]
	connection_type = new_config_data["connection_type"]
	if connection_type == Enums.ConnectionType.LOCAL:
		local_opponent = new_config_data["local_opponent"]
	
	# remove this object if game mode is not crazyhouse
	if new_config_data["game_mode"] != Enums.GameMode.CRAZY_HOUSE:
		queue_free()
		return
	
	# reverse vertical gui elements if player side is black (default order is white)
	if player_color == Enums.ChessColor.BLACK:
		$black.position.y = 92.0
		$white.position.y = 36.0
	
	# connect all buttons signals if game is "local human vs human" else connect just player side button signals
	if connection_type == Enums.ConnectionType.LOCAL and local_opponent == Enums.LocalOpponent.HUMAN:
		for white_element_node: Control in white_elements_node.get_children():
			if white_element_node is Button:
				white_element_node.pressed.connect(_on_piece_button_pressed.bind(white_element_node, Enums.ChessColor.WHITE))
		for black_element_node: Control in black_elements_node.get_children():
			if black_element_node is Button:
				black_element_node.pressed.connect(_on_piece_button_pressed.bind(black_element_node, Enums.ChessColor.BLACK))
	else:
		match player_color:
			Enums.ChessColor.WHITE:
				for white_element_node: Control in white_elements_node.get_children():
					if white_element_node is Button:
						white_element_node.pressed.connect(_on_piece_button_pressed.bind(white_element_node, Enums.ChessColor.WHITE))
				for black_element_node: Control in black_elements_node.get_children():
					if black_element_node is Button:
						black_element_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			Enums.ChessColor.BLACK:
				for black_element_node: Control in black_elements_node.get_children():
					if black_element_node is Button:
						black_element_node.pressed.connect(_on_piece_button_pressed.bind(black_element_node, Enums.ChessColor.BLACK))
				for white_element_node: Control in white_elements_node.get_children():
					if white_element_node is Button:
						white_element_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	show()


func _on_move_applied(_move_type: Enums.MoveType, _from: String, _to: String) -> void:
	update_gui()
	selected_button = null
	selected_piece_marker_node.hide()


func _on_promotion_piece_updated(_from: String, _to: String, _role: Enums.PieceRole) -> void:
	_on_move_applied(Enums.MoveType.NORMAL, "", "")


func _on_put_move_applied(_role: Enums.PieceRole, _to: String) -> void:
	_on_move_applied(Enums.MoveType.NORMAL, "", "")


func _on_undoed_last_move(_double_undo: bool):
	_on_move_applied(Enums.MoveType.NORMAL, "", "")


func update_gui() -> void:
	for element_vector: Vector3i in master_scene.get_crazyhouse_pockets(): # x = color, y = role, z = value
		var color_string: String
		match element_vector.x as Enums.ChessColor:
			Enums.ChessColor.WHITE: color_string = "white"
			Enums.ChessColor.BLACK: color_string = "black"
		
		var piece_role_string: String
		match element_vector.y as Enums.PieceRole:
			Enums.PieceRole.QUEEN: piece_role_string = "queen"
			Enums.PieceRole.BISHOP: piece_role_string = "bishop"
			Enums.PieceRole.KNIGHT: piece_role_string = "knight"
			Enums.PieceRole.ROOK: piece_role_string = "rook"
			Enums.PieceRole.PAWN: piece_role_string = "pawn"
		
		var button: Button = get_node(color_string + "/" + piece_role_string + "_button")
		var label: Label = get_node(color_string + "/" + piece_role_string + "_label")
		var value: int = element_vector.z
		
		label.text = str(value)
		
		if value <= 0:
			button.disabled = true
		else:
			button.disabled = false
	
	# all button are pressable in local human vs human mode, only allow active side buttons press
	if connection_type == Enums.ConnectionType.LOCAL and local_opponent == Enums.LocalOpponent.HUMAN:
		match master_scene.get_turn():
			Enums.ChessColor.WHITE:
				for white_element_node: Control in white_elements_node.get_children():
					if white_element_node is Button:
						white_element_node.mouse_filter = Control.MOUSE_FILTER_STOP
				for black_element_node: Control in black_elements_node.get_children():
					if black_element_node is Button:
						black_element_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			Enums.ChessColor.BLACK:
				for black_element_node: Control in black_elements_node.get_children():
					if black_element_node is Button:
						black_element_node.mouse_filter = Control.MOUSE_FILTER_STOP
				for white_element_node: Control in white_elements_node.get_children():
					if white_element_node is Button:
						white_element_node.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_piece_button_pressed(pressed_button: Button, piece_color: Enums.ChessColor) -> void:
	Sound.button_tick.play()
	
	if selected_button != pressed_button and piece_color == master_scene.get_turn():
		var piece_role: Enums.PieceRole
		match pressed_button.name:
			"queen_button": piece_role = Enums.PieceRole.QUEEN
			"rook_button": piece_role = Enums.PieceRole.ROOK
			"bishop_button": piece_role = Enums.PieceRole.BISHOP
			"knight_button": piece_role = Enums.PieceRole.KNIGHT
			"pawn_button": piece_role = Enums.PieceRole.PAWN
		
		selected_button = pressed_button
		selected_piece_marker_node.position = pressed_button.global_position - Vector2(1.0, 1.0)
		selected_piece_marker_node.show()
		piece_selected_for_put_move.emit(piece_role)
	else:
		selected_button = null
		selected_piece_marker_node.hide()
		piece_unselected_for_put_move.emit()
