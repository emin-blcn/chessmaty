extends Control

@onready var master_scene: Control = get_tree().current_scene
@onready var selected_piece_marker_node: Panel = $selected_piece_marker
@onready var white_piece_buttons: Array[Button] = [$white/queen_button, $white/rook_button, $white/bishop_button, $white/knight_button, $white/pawn_button]
@onready var white_piece_count_labels: Array[Label] = [$white/queen_label, $white/rook_label, $white/bishop_label, $white/knight_label, $white/pawn_label]
@onready var black_piece_buttons: Array[Button] = [$black/queen_button, $black/rook_button, $black/bishop_button, $black/knight_button, $black/pawn_button]
@onready var black_piece_count_labels: Array[Label] = [$black/queen_label, $black/rook_label, $black/bishop_label, $black/knight_label, $black/pawn_label]

var player_color: Enums.ChessColor
var connection_type: Enums.ConnectionType
var local_opponent: Enums.LocalOpponent
var selected_button: Button


func config(new_config_data: Dictionary[String, Variant]) -> void:
	player_color = new_config_data["player_color"]
	connection_type = new_config_data["connection_type"]
	if connection_type == Enums.ConnectionType.LOCAL:
		local_opponent = new_config_data["local_opponent"]
	
	# remove this object if game mode is not crazyhouse
	if new_config_data["game_mode"] != Enums.GameMode.CRAZY_HOUSE:
		queue_free()
		return
	
	if player_color == Enums.ChessColor.BLACK:
		$black.position.y = 92.0
		$white.position.y = 36.0
	
	# connect all buttons signals if game is "local human vs human" else connect just player side button signals
	if connection_type == Enums.ConnectionType.LOCAL and local_opponent == Enums.LocalOpponent.HUMAN:
		for white_piece_button: Button in white_piece_buttons:
			white_piece_button.pressed.connect(_on_piece_button_pressed.bind(white_piece_button, Enums.ChessColor.WHITE))
		for black_piece_button: Button in black_piece_buttons:
			black_piece_button.pressed.connect(_on_piece_button_pressed.bind(black_piece_button, Enums.ChessColor.BLACK))
	else:
		match player_color:
			Enums.ChessColor.WHITE:
				for white_piece_button: Button in white_piece_buttons:
					white_piece_button.pressed.connect(_on_piece_button_pressed.bind(white_piece_button, Enums.ChessColor.WHITE))
			Enums.ChessColor.BLACK:
				for black_piece_button: Button in black_piece_buttons:
					black_piece_button.pressed.connect(_on_piece_button_pressed.bind(black_piece_button, Enums.ChessColor.BLACK))
	show()


func _on_move_animation_started(_move_type: Enums.MoveType, _from: String, _to: String) -> void:
	match master_scene.get_turn():
		Enums.ChessColor.WHITE:
			update_black_gui()
		Enums.ChessColor.BLACK:
			update_white_gui()


func update_white_gui() -> void:
	var pocket_white_pieces: Dictionary[Enums.Piece, int] = master_scene.get_crazyhouse_pocket_white_pieces()
	for piece_role: Enums.Piece in pocket_white_pieces.keys():
		var piece_role_string: String
		match piece_role:
			Enums.Piece.QUEEN: piece_role_string = "queen"
			Enums.Piece.ROOK: piece_role_string = "rook"
			Enums.Piece.BISHOP: piece_role_string = "bishop"
			Enums.Piece.KNIGHT: piece_role_string = "knight"
			Enums.Piece.PAWN: piece_role_string = "pawn"
			
		var button: Button = get_node("white/" + piece_role_string + "_button")
		var label: Label = get_node("white/" + piece_role_string + "_label")
		var new_count: int = pocket_white_pieces[piece_role]
		
		if new_count <= 0:
			label.text = "0"
			button.disabled = true
		else:
			label.text = str(new_count)
			if player_color == Enums.ChessColor.WHITE or (connection_type == Enums.ConnectionType.LOCAL and local_opponent == Enums.LocalOpponent.HUMAN):
				button.disabled = false
	
	if connection_type != Enums.ConnectionType.LOCAL or local_opponent != Enums.LocalOpponent.HUMAN:
		return
	
	for i in range(5):
		if black_piece_count_labels[i].text != "0":
			black_piece_buttons[i].disabled = false
	for white_button in white_piece_buttons:
		white_button.disabled = true


func update_black_gui() -> void:
	var pocket_black_pieces: Dictionary[Enums.Piece, int] = master_scene.get_crazyhouse_pocket_black_pieces()
	for piece_role: Enums.Piece in pocket_black_pieces.keys():
		var piece_role_string: String
		match piece_role:
			Enums.Piece.QUEEN: piece_role_string = "queen"
			Enums.Piece.ROOK: piece_role_string = "rook"
			Enums.Piece.BISHOP: piece_role_string = "bishop"
			Enums.Piece.KNIGHT: piece_role_string = "knight"
			Enums.Piece.PAWN: piece_role_string = "pawn"
			
		var button: Button = get_node("black/" + piece_role_string + "_button")
		var label: Label = get_node("black/" + piece_role_string + "_label")
		var new_count: int = pocket_black_pieces[piece_role]
		
		if new_count <= 0:
			label.text = "0"
			button.disabled = true
		else:
			label.text = str(new_count)
			if player_color == Enums.ChessColor.BLACK or (connection_type == Enums.ConnectionType.LOCAL and local_opponent == Enums.LocalOpponent.HUMAN):
				button.disabled = false
	
	if connection_type != Enums.ConnectionType.LOCAL or local_opponent != Enums.LocalOpponent.HUMAN:
		return
	
	for i in range(5):
		if white_piece_count_labels[i].text != "0":
			white_piece_buttons[i].disabled = false
	for black_button in black_piece_buttons:
		black_button.disabled = true


func _on_piece_button_pressed(pressed_button: Button, piece_color: Enums.ChessColor) -> void:
	Sound.button_tick.play()
	if selected_button != pressed_button and piece_color == master_scene.get_turn():
		var piece_role: Enums.Piece
		match pressed_button.name:
			"queen_button": piece_role = Enums.Piece.QUEEN
			"rook_button": piece_role = Enums.Piece.ROOK
			"bishop_button": piece_role = Enums.Piece.BISHOP
			"knight_button": piece_role = Enums.Piece.KNIGHT
			"pawn_button": piece_role = Enums.Piece.PAWN
		
		selected_button = pressed_button
		selected_piece_marker_node.position = pressed_button.global_position - Vector2(1.0, 1.0)
		selected_piece_marker_node.show()
		master_scene._on_selected_piece_for_put_move(piece_role)
	else:
		selected_button = null
		selected_piece_marker_node.hide()
		master_scene._on_unselected_piece_for_put_move()


func _on_put_move_applied() -> void:
	selected_button = null
	selected_piece_marker_node.hide()
