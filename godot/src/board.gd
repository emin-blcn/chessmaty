extends Control

signal move_animation_started(move_type: Enums.MoveType, from: String, to: String)
signal move_animation_finished(move_type: Enums.MoveType)

const MOVE_ANIMATION_DURATION: float = 0.3
const PIECE_TEXTURES: Dictionary[Array, Resource] = {
	[Enums.Piece.KING, Enums.ChessColor.WHITE]: preload("uid://cags18jbwmm0d"),
	[Enums.Piece.KING, Enums.ChessColor.BLACK]: preload("uid://dioyjnoc4d7vu"),
	[Enums.Piece.QUEEN, Enums.ChessColor.WHITE]: preload("uid://cfi88xmcwl8xv"),
	[Enums.Piece.QUEEN, Enums.ChessColor.BLACK]: preload("uid://cp7h3f6nl280m"),
	[Enums.Piece.BISHOP, Enums.ChessColor.WHITE]: preload("uid://cnkaj6a1nvawt"),
	[Enums.Piece.BISHOP, Enums.ChessColor.BLACK]: preload("uid://dnip4r75iln63"),
	[Enums.Piece.KNIGHT, Enums.ChessColor.WHITE]: preload("uid://bb6wpbdxlg4jl"),
	[Enums.Piece.KNIGHT, Enums.ChessColor.BLACK]: preload("uid://b1qiry1fgwq7y"),
	[Enums.Piece.ROOK, Enums.ChessColor.WHITE]: preload("uid://b43npdubwnbj"),
	[Enums.Piece.ROOK, Enums.ChessColor.BLACK]: preload("uid://cdw8mxfjy7wn3"),
	[Enums.Piece.PAWN, Enums.ChessColor.WHITE]: preload("uid://dcolfenoo2rm8"),
	[Enums.Piece.PAWN, Enums.ChessColor.BLACK]: preload("uid://ccn6a7hxwydu")}
const MARKER_TEXTURES: Dictionary[String, CompressedTexture2D] = {
	"white": preload("uid://cy6eriq3qj3nw"),
	"green": preload("uid://dffcgne8d5luw"),
	"yellow": preload("uid://b1r2lw2861tk8"),
	"red": preload("uid://cwiw00cwqqit2")}
const KINGS_POSSIBLE_TARGET_SQUARES_IN_CASTLING_MOVE: PackedStringArray = ["g1", "g8", "c1", "c8"]

@onready var master_scene: Control = get_tree().current_scene
@onready var piece_nodes: Control = $piece_nodes
@onready var marker_nodes: Control = $marker_nodes
@onready var input_control_node: Control = $input_conrol

var player_color: Enums.ChessColor
var game_mode: Enums.GameMode
var connection_type: Enums.ConnectionType
var local_opponent: Enums.LocalOpponent
var active_square: String
var current_turn: Enums.ChessColor
var legal_moves: Dictionary[String, Enums.MoveType]
var legal_put_moves: PackedStringArray
var king_in_danger_square: String
var _is_move_animation_playing: bool
var any_piece_selected: bool
var selected_piece_for_put_move: Enums.Piece = Enums.Piece.EMPTY
var piece_nodes_on_board: Dictionary[String, TextureRect] = {
	"a8": null, "b8": null, "c8": null, "d8": null, "e8": null, "f8": null, "g8": null, "h8": null,
	"a7": null, "b7": null, "c7": null, "d7": null, "e7": null, "f7": null, "g7": null, "h7": null,
	"a6": null, "b6": null, "c6": null, "d6": null, "e6": null, "f6": null, "g6": null, "h6": null,
	"a5": null, "b5": null, "c5": null, "d5": null, "e5": null, "f5": null, "g5": null, "h5": null,
	"a4": null, "b4": null, "c4": null, "d4": null, "e4": null, "f4": null, "g4": null, "h4": null,
	"a3": null, "b3": null, "c3": null, "d3": null, "e3": null, "f3": null, "g3": null, "h3": null,
	"a2": null, "b2": null, "c2": null, "d2": null, "e2": null, "f2": null, "g2": null, "h2": null,
	"a1": null, "b1": null, "c1": null, "d1": null, "e1": null, "f1": null, "g1": null, "h1": null}


func config(new_config_data: Dictionary[String, Variant]) -> void:
	player_color = new_config_data["player_color"]
	game_mode = new_config_data["game_mode"]
	connection_type = new_config_data["connection_type"]
	
	if game_mode != Enums.GameMode.KING_OF_THE_HILL:
		$king_of_the_hill_color_rect.queue_free()
	
	if game_mode != Enums.GameMode.RACING_KINGS:
		$racing_kings_color_rect.queue_free()
	
	if connection_type == Enums.ConnectionType.LOCAL:
		local_opponent = new_config_data["local_opponent"]
	
	update_all_pieces()
	
	# reverse numbers and letters if player color is black (and game mode is not "Racing Kings")
	if player_color == Enums.ChessColor.BLACK and game_mode != Enums.GameMode.RACING_KINGS:
		for i in range(0, 8):
			$numbers_left.get_child(i).text = "12345678"[i]
			$numbers_right.get_child(i).text = "12345678"[i]
			$letters_top.get_child(i).text = "HGFEDCBA"[i]
			$letters_bottom.get_child(i).text = "HGFEDCBA"[i]


func update_all_pieces() -> void:
	# synchronize Godot with Rust
	for number in "87654321":
		for letter in "abcdefgh":
			var square: String = letter + number
			var rust_piece: Enums.Piece = master_scene.get_piece_role_from_square(square)
			var godot_piece_node: TextureRect = piece_nodes_on_board[square]
			
			if rust_piece == Enums.Piece.EMPTY:
				if godot_piece_node != null:
					piece_nodes_on_board[square] = null
					godot_piece_node.queue_free()
			else:
				var piece_color: Enums.ChessColor = master_scene.get_piece_color_from_square(square)
				if godot_piece_node == null:
					var new_piece: TextureRect = new_piece_node(rust_piece, piece_color, square)
					piece_nodes_on_board[square] = new_piece
					piece_nodes.add_child(new_piece)
				else:
					godot_piece_node.texture = PIECE_TEXTURES[ [rust_piece, piece_color] ]


func new_piece_node(piece: Enums.Piece, piece_color: Enums.ChessColor, square: String) -> TextureRect:
	var new_node: TextureRect = TextureRect.new()
	new_node.size = Vector2(16.0, 32.0)
	new_node.offset_transform_enabled = true
	new_node.offset_transform_position.y = -19
	new_node.position = square_to_position(square)
	new_node.texture = PIECE_TEXTURES[ [piece, piece_color] ]
	return new_node


func is_move_animation_playing() -> bool:
	return _is_move_animation_playing


func _on_input_conrol_mouse_exited() -> void:
	if any_piece_selected:
		return
	
	var old_marker_node: TextureRect = marker_nodes.get_node_or_null(active_square)
	if old_marker_node != null:
		if active_square == king_in_danger_square:
			old_marker_node.texture = MARKER_TEXTURES["red"]
		else:
			old_marker_node.queue_free()
	
	active_square = ""


func _on_input_conrol_gui_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		if event is InputEventMouseMotion:
			hovering_on_board_event( position_to_square(event.position) )
		if event is InputEventMouseButton:
			if event.is_pressed() and event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
				selected_piece_event( position_to_square(event.position) )


func hovering_on_board_event(new_square: String) -> void:
	if any_piece_selected or new_square == active_square or is_move_animation_playing() or (game_mode == Enums.GameMode.CRAZY_HOUSE and selected_piece_for_put_move != Enums.Piece.EMPTY):
		return
	
	var old_marker_node: TextureRect = marker_nodes.get_node_or_null(active_square)
	if old_marker_node != null:
		if active_square == king_in_danger_square:
			old_marker_node.texture = MARKER_TEXTURES["red"]
		else:
			old_marker_node.queue_free()
	
	if piece_nodes_on_board[new_square] != null:
		if piece_in_this_square_is_playable(new_square):
			if new_square == king_in_danger_square:
				marker_nodes.get_node(new_square).texture = MARKER_TEXTURES["white"]
			else:
				add_marker(new_square, "white")
	
	active_square = new_square


func selected_piece_event(new_square: String) -> void:
	if is_move_animation_playing():
		return
	
	if game_mode == Enums.GameMode.CRAZY_HOUSE and selected_piece_for_put_move != Enums.Piece.EMPTY:
		if legal_put_moves.has(new_square):
			master_scene.appy_put_move(selected_piece_for_put_move, new_square)
			selected_piece_for_put_move = Enums.Piece.EMPTY
			clear_markers()
		return
	
	if !any_piece_selected:
		if piece_nodes_on_board[new_square] != null:
			var piece: Enums.Piece = master_scene.get_piece_role_from_square(new_square)
			if piece != Enums.Piece.EMPTY:
				if piece_in_this_square_is_playable(new_square):
					Sound.select.play()
					any_piece_selected = true
					active_square = new_square
					legal_moves = master_scene.get_legal_moves_from_square(new_square)
					add_legal_move_markers()
	elif any_piece_selected:
		# cancel selection if selected piece clicked again
		if new_square == active_square:
			any_piece_selected = false
			clear_markers()
		else:
			# apply move if move is legal
			if legal_moves.has(new_square):
				hide_input_control_node()
				_is_move_animation_playing = true
				any_piece_selected = false
				clear_markers()
				match legal_moves[new_square]:
					Enums.MoveType.NORMAL:
						master_scene.apply_normal_move(active_square, new_square)
					Enums.MoveType.EN_PASSANT:
						master_scene.apply_en_passant_move(active_square, new_square)
					Enums.MoveType.PROMOTION:
						self._on_chess_logic_move_applied(Enums.MoveType.PROMOTION_REQUEST_BY_HUMAN, active_square, new_square, Enums.Piece.EMPTY)
					# apply castling move if rook's square is clicked (chess960 format)
					Enums.MoveType.CASTLING:
						master_scene.apply_castling_move(active_square, new_square)
			else:
				# also apply castling move if king's target square is clicked
				if KINGS_POSSIBLE_TARGET_SQUARES_IN_CASTLING_MOVE.has(new_square):
					var rook_from_square_in_castling_move: String = get_rook_from_square_in_castling_move(new_square)
					if legal_moves.has(rook_from_square_in_castling_move):
						if legal_moves[rook_from_square_in_castling_move] == Enums.MoveType.CASTLING:
							hide_input_control_node()
							_is_move_animation_playing = true
							any_piece_selected = false
							clear_markers()
							master_scene.apply_castling_move(active_square, rook_from_square_in_castling_move)
							return
				
				# switch selection if clicked square contains a piece and piece's owner is current player
				if piece_nodes_on_board[new_square] != null:
					var piece: Enums.Piece = master_scene.get_piece_role_from_square(new_square)
					if piece != Enums.Piece.EMPTY:
						if piece_in_this_square_is_playable(new_square):
							Sound.select.play()
							active_square = new_square
							legal_moves = master_scene.get_legal_moves_from_square(new_square)
							clear_markers()
							add_legal_move_markers()
							add_marker(new_square, "white")


func _on_selected_piece_for_put_move(piece_role: Enums.Piece) -> void:
	selected_piece_for_put_move = piece_role
	any_piece_selected = false
	clear_markers()
	legal_put_moves = master_scene.get_legal_put_moves_from_role(piece_role)
	add_legal_put_move_markers()


func _on_unselected_piece_for_put_move() -> void:
	selected_piece_for_put_move = Enums.Piece.EMPTY
	clear_markers()


func get_rook_from_square_in_castling_move(king_target_square: String) -> String:
	if game_mode == Enums.GameMode.CHESS960:
		for letter in "hgfedcba" if king_target_square.begins_with("g") else "abcdefgh":
			var square: String = letter + king_target_square[1]
			if piece_nodes_on_board[square] != null: 
				if master_scene.get_piece_role_from_square(square) == Enums.Piece.ROOK:
					return letter + king_target_square[1]
	
	match king_target_square:
		"g1": return "h1"
		"g8": return "h8"
		"c1": return "a1"
		"c8": return "a8"
	
	return ""


func get_king_target_square_in_castling_move(king_from_square: String, rook_from_square: String) -> String:
	var is_king_side: bool = rook_from_square[0] > king_from_square[0]
	return ("g" if is_king_side else "c") + king_from_square[1]


func get_rook_target_square_in_castling_move(king_from_square: String, rook_from_square: String) -> String:
	var is_king_side: bool = rook_from_square[0] > king_from_square[0]
	return ("f" if is_king_side else "d") + king_from_square[1]


func piece_in_this_square_is_playable(square: String) -> bool:
	var piece_color: Enums.ChessColor = master_scene.get_piece_color_from_square(square)
	if piece_color == current_turn:
		if piece_color == player_color:
			return true
		elif connection_type == Enums.ConnectionType.LOCAL and local_opponent == Enums.LocalOpponent.HUMAN:
			return true
		else:
			return false
	else:
		return false


func _on_chess_logic_move_applied(move_type: Enums.MoveType, from: String, to: String, promotion_or_put_role: Enums.Piece) -> void:
	move_animation_started.emit(move_type, from, to)
	
	if move_type == Enums.MoveType.UNDO:
		if marker_nodes.get_child_count() > 0:
			clear_markers()
		_on_move_animation_tween_finished(move_type)
		return
	
	var tween: Tween = create_tween().set_parallel(true)
	tween.pause()
	tween.finished.connect(_on_move_animation_tween_finished.bind(move_type))
	match move_type:
		Enums.MoveType.NORMAL:
			apply_normal_move(from, to, tween)
		Enums.MoveType.EN_PASSANT:
			apply_en_passant_move(from, to, tween)
		Enums.MoveType.CASTLING:
			apply_castling_move(from, to, tween)
		Enums.MoveType.PROMOTION_REQUEST_BY_HUMAN:
			apply_normal_move(from, to, tween)
		Enums.MoveType.PROMOTION_REQUEST_BY_AI:
			apply_normal_move(from, to, tween)
			master_scene.update_ai_selected_promotion_role(promotion_or_put_role)
		Enums.MoveType.PROMOTION:
			if master_scene.get_connection_type() == Enums.ConnectionType.LAN and player_color != current_turn:
				apply_normal_move(from, to, tween)
				update_promotion_piece(to, promotion_or_put_role)
			else:
				update_promotion_piece(to, promotion_or_put_role)
				_on_move_animation_tween_finished(move_type)
				return
		Enums.MoveType.PUT:
			apply_put_move(to, promotion_or_put_role)
			return
	tween.play()


func apply_normal_move(from_square: String, to_square: String, tween: Tween) -> void:
	var from_piece_node: Control = piece_nodes_on_board[from_square]
	piece_nodes_on_board[from_square] = null
	tween.tween_property(from_piece_node, "position", square_to_position(to_square), MOVE_ANIMATION_DURATION)
	
	# remove enemy piece if target square contains an enemy piece
	var to_piece_node: TextureRect = piece_nodes_on_board[to_square]
	if to_piece_node != null:
		tween.tween_property(to_piece_node, "modulate:a", 0.0, MOVE_ANIMATION_DURATION / 2.0)
		tween.finished.connect(to_piece_node.queue_free)
		tween.finished.connect(Sound.capture.play)
		
		if game_mode == Enums.GameMode.ATOMIC:
			tween.tween_property(from_piece_node, "modulate:a", 0.0, MOVE_ANIMATION_DURATION)
			tween.finished.connect(from_piece_node.queue_free)
			explode_3x3_area_in_atomic_mode(to_square, tween)
			return
	
	piece_nodes_on_board[to_square] = from_piece_node
	tween.finished.connect(Sound.move.play)


func apply_en_passant_move(pawn_from_square: String, pawn_to_square: String, tween: Tween) -> void:
	var from_pawn_node: Control = piece_nodes_on_board[pawn_from_square]
	piece_nodes_on_board[pawn_from_square] = null
	tween.tween_property(from_pawn_node, "position", square_to_position(pawn_to_square), MOVE_ANIMATION_DURATION)
	
	if game_mode == Enums.GameMode.ATOMIC:
		tween.tween_property(from_pawn_node, "modulate:a", 0.0, MOVE_ANIMATION_DURATION)
		tween.finished.connect(from_pawn_node.queue_free)
		explode_3x3_area_in_atomic_mode(pawn_to_square, tween)
	else:
		piece_nodes_on_board[pawn_to_square] = from_pawn_node
	
	# captured pawn square = moving pawn's target file + start rank 
	var captured_pawn_square: String = pawn_to_square[0] + pawn_from_square[1]
	var captured_pawn_node: TextureRect = piece_nodes_on_board[captured_pawn_square]
	piece_nodes_on_board[captured_pawn_square] = null
	tween.tween_property(captured_pawn_node, "modulate:a", 0.0, MOVE_ANIMATION_DURATION / 2.0)
	tween.finished.connect(captured_pawn_node.queue_free)
	tween.finished.connect(Sound.capture.play)


func apply_castling_move(king_from_square: String, rook_from_square: String, tween: Tween) -> void:
	# castling move came chess960 format, get king and rook target squares for godot
	var king_node: TextureRect = piece_nodes_on_board[king_from_square]
	var rook_node: TextureRect = piece_nodes_on_board[rook_from_square]
	piece_nodes_on_board[king_from_square] = null
	piece_nodes_on_board[rook_from_square] = null
	
	var king_to_square: String = get_king_target_square_in_castling_move(king_from_square, rook_from_square)
	var rook_to_square: String = get_rook_target_square_in_castling_move(king_from_square, rook_from_square)
	piece_nodes_on_board[king_to_square] = king_node
	piece_nodes_on_board[rook_to_square] = rook_node
	
	tween.tween_property(king_node, "position", square_to_position(king_to_square), MOVE_ANIMATION_DURATION)
	tween.tween_property(rook_node, "position", square_to_position(rook_to_square), MOVE_ANIMATION_DURATION)
	tween.finished.connect(Sound.move.play)


func update_promotion_piece(square: String, new_role: Enums.Piece) -> void:
	var color: Enums.ChessColor
	match square[1]:
		"8": color = Enums.ChessColor.WHITE
		"1": color = Enums.ChessColor.BLACK
	
	piece_nodes_on_board[square].texture = PIECE_TEXTURES[ [new_role, color] ]


func apply_put_move(square: String, new_role: Enums.Piece) -> void:
	var _new_piece_node: TextureRect = new_piece_node(new_role, current_turn, square)
	piece_nodes_on_board[square] = _new_piece_node
	piece_nodes.add_child(_new_piece_node)
	_on_move_animation_tween_finished(Enums.MoveType.PUT)
	Sound.move.play()


func explode_3x3_area_in_atomic_mode(square: String, tween: Tween) -> void:
	var square_position: Vector2 = square_to_position(square) + Vector2(8.0, 8.0)
	var target_square_positions: PackedVector2Array = [
		square_position + Vector2(-16.0, -16.0),
		square_position + Vector2(0.0, -16.0),
		square_position + Vector2(16.0, -16.0),
		square_position + Vector2(-16.0, 0.0),
		square_position + Vector2(16.0, 0.0),
		square_position + Vector2(16.0, 16.0),
		square_position + Vector2(0.0, 16.0),
		square_position + Vector2(-16.0, 16.0)]
	
	for sq_pos in target_square_positions:
		if sq_pos.x < 0.0 or sq_pos.x > 128.0 or sq_pos.y < 0.0 or sq_pos.y > 128.0:
			continue
			
		var target_square: String = position_to_square(sq_pos)
		if master_scene.get_piece_role_from_square(target_square) == Enums.Piece.PAWN:
			continue
		
		var target_piece_node: TextureRect = piece_nodes_on_board[target_square]
		if target_piece_node != null:
			piece_nodes_on_board[target_square] = null
			tween.tween_property(target_piece_node, "modulate:a", 0.0, MOVE_ANIMATION_DURATION / 2.0)
			tween.finished.connect(target_piece_node.queue_free)


func _on_move_animation_tween_finished(move_type: Enums.MoveType) -> void:
	current_turn = master_scene.get_turn()
	move_animation_finished.emit(move_type)
	
	var new_king_in_danger_squre: String = master_scene.get_king_in_danger_square()
	if !king_in_danger_square.is_empty() and king_in_danger_square != new_king_in_danger_squre:
		# a king was in danger in previous move and king's not dangered in new move
		var old_king_in_danger: String = king_in_danger_square
		king_in_danger_square = ""
		var old_king_in_danger_marker_node = marker_nodes.get_node_or_null(old_king_in_danger)
		if old_king_in_danger_marker_node != null:
			marker_nodes.get_node(old_king_in_danger).queue_free()
	
	king_in_danger_square = new_king_in_danger_squre
	
	if !king_in_danger_square.is_empty():
		# a king in danger in new move
		add_marker(new_king_in_danger_squre, "red")
	
	_is_move_animation_playing = false


func hide_input_control_node() -> void:
	input_control_node.hide()


func show_input_control_node() -> void:
	input_control_node.show()


func add_legal_move_markers() -> void:
	if active_square == king_in_danger_square:
		marker_nodes.get_node(active_square).texture = MARKER_TEXTURES["white"]
	else:
		if marker_nodes.get_node_or_null(active_square) == null:
			add_marker(active_square, "white")
	
	for legal_move_square: String in legal_moves.keys():
		var move_type: Enums.MoveType = legal_moves[legal_move_square] as Enums.MoveType
		var piece: Enums.Piece = Enums.Piece.EMPTY if piece_nodes_on_board[legal_move_square] == null else master_scene.get_piece_role_from_square(legal_move_square)
		
		if move_type == Enums.MoveType.CASTLING:
			add_marker(legal_move_square, "yellow")
			var king_target_square: String = get_king_target_square_in_castling_move(active_square, legal_move_square)
			
			if king_target_square != active_square and !legal_moves.has(king_target_square):
				add_marker(king_target_square, "yellow")
		elif move_type ==  Enums.MoveType.EN_PASSANT or move_type == Enums.MoveType.PROMOTION:
			add_marker(legal_move_square, "yellow")
		elif piece == Enums.Piece.EMPTY:
			add_marker(legal_move_square, "green")
		else:
			add_marker(legal_move_square, "red")


func add_legal_put_move_markers() -> void:
	for legal_put_move in legal_put_moves:
		add_marker(legal_put_move, "white")


func add_marker(square: String, color: String) -> void:
	var new_node: TextureRect = TextureRect.new()
	new_node.name = square
	new_node.size = Vector2(16.0, 16.0)
	new_node.position = square_to_position(square)
	new_node.texture = MARKER_TEXTURES[color]
	marker_nodes.add_child(new_node)


func clear_markers() -> void:
	for child: TextureRect in marker_nodes.get_children():
		if !is_move_animation_playing() and !king_in_danger_square.is_empty() and child.name == king_in_danger_square:
			child.texture = MARKER_TEXTURES["red"]
		else:
			child.queue_free()


func position_to_square(input_position: Vector2) -> String:
	var square_vector: Vector2i = input_position.clamp(Vector2.ZERO, Vector2(127.0, 127.0)) / 16.0
	var letters: String = "abcdefgh" if player_color == Enums.ChessColor.WHITE or game_mode == Enums.GameMode.RACING_KINGS else "hgfedcba"
	var numbers: String = "87654321" if player_color == Enums.ChessColor.WHITE or game_mode == Enums.GameMode.RACING_KINGS else "12345678"
	return letters[square_vector.x] + numbers[square_vector.y]


func square_to_position(square: String) -> Vector2:
	var letters: String = "abcdefgh" if player_color == Enums.ChessColor.WHITE or game_mode == Enums.GameMode.RACING_KINGS else "hgfedcba"
	var numbers: String = "87654321" if player_color == Enums.ChessColor.WHITE or game_mode == Enums.GameMode.RACING_KINGS else "12345678"
	return Vector2(letters.find(square[0]) * 16.0, numbers.find(square[1]) * 16.0)
