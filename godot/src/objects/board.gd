extends Control

signal move_animation_finished()
signal promotion_selection_required()

const MOVE_ANIMATION_DURATION: float = 0.3
const PIECE_TEXTURES: Dictionary[Vector2i, CompressedTexture2D] = {
	Vector2i(Enums.PieceRole.KING, Enums.ChessColor.WHITE): preload("uid://cags18jbwmm0d"),
	Vector2i(Enums.PieceRole.KING, Enums.ChessColor.BLACK): preload("uid://dioyjnoc4d7vu"),
	Vector2i(Enums.PieceRole.QUEEN, Enums.ChessColor.WHITE): preload("uid://cfi88xmcwl8xv"),
	Vector2i(Enums.PieceRole.QUEEN, Enums.ChessColor.BLACK): preload("uid://cp7h3f6nl280m"),
	Vector2i(Enums.PieceRole.BISHOP, Enums.ChessColor.WHITE): preload("uid://cnkaj6a1nvawt"),
	Vector2i(Enums.PieceRole.BISHOP, Enums.ChessColor.BLACK): preload("uid://dnip4r75iln63"),
	Vector2i(Enums.PieceRole.KNIGHT, Enums.ChessColor.WHITE): preload("uid://bb6wpbdxlg4jl"),
	Vector2i(Enums.PieceRole.KNIGHT, Enums.ChessColor.BLACK): preload("uid://b1qiry1fgwq7y"),
	Vector2i(Enums.PieceRole.ROOK, Enums.ChessColor.WHITE): preload("uid://b43npdubwnbj"),
	Vector2i(Enums.PieceRole.ROOK, Enums.ChessColor.BLACK): preload("uid://cdw8mxfjy7wn3"),
	Vector2i(Enums.PieceRole.PAWN, Enums.ChessColor.WHITE): preload("uid://dcolfenoo2rm8"),
	Vector2i(Enums.PieceRole.PAWN, Enums.ChessColor.BLACK): preload("uid://ccn6a7hxwydu")}
const MOVE_MARKER_TEXTURES: Dictionary[String, CompressedTexture2D] = {
	"white": preload("uid://cy6eriq3qj3nw"),
	"green": preload("uid://dffcgne8d5luw"),
	"yellow": preload("uid://b1r2lw2861tk8"),
	"red": preload("uid://cwiw00cwqqit2")}
const KINGS_POSSIBLE_TARGET_SQUARES_IN_CASTLING_MOVE: PackedStringArray = ["g1", "g8", "c1", "c8"]

var player_color: Enums.ChessColor
var game_mode: Enums.GameMode
var connection_type: Enums.ConnectionType
var local_opponent: Enums.LocalOpponent
var active_square: String
var active_turn: Enums.ChessColor
var legal_moves: Dictionary[String, Enums.MoveType]
var legal_put_moves: PackedStringArray
var king_in_danger_square: String
var move_animation_tween: Tween
var _is_move_animation_playing: bool
var any_piece_selected: bool
var selected_piece_for_put_move: Enums.PieceRole = Enums.PieceRole.EMPTY
var piece_nodes_on_board: Dictionary[String, TextureRect] = {
	"a8": null, "b8": null, "c8": null, "d8": null, "e8": null, "f8": null, "g8": null, "h8": null,
	"a7": null, "b7": null, "c7": null, "d7": null, "e7": null, "f7": null, "g7": null, "h7": null,
	"a6": null, "b6": null, "c6": null, "d6": null, "e6": null, "f6": null, "g6": null, "h6": null,
	"a5": null, "b5": null, "c5": null, "d5": null, "e5": null, "f5": null, "g5": null, "h5": null,
	"a4": null, "b4": null, "c4": null, "d4": null, "e4": null, "f4": null, "g4": null, "h4": null,
	"a3": null, "b3": null, "c3": null, "d3": null, "e3": null, "f3": null, "g3": null, "h3": null,
	"a2": null, "b2": null, "c2": null, "d2": null, "e2": null, "f2": null, "g2": null, "h2": null,
	"a1": null, "b1": null, "c1": null, "d1": null, "e1": null, "f1": null, "g1": null, "h1": null}

@onready var master_scene: Control = get_tree().current_scene
@onready var piece_textures_node: Control = $piece_textures
@onready var move_marker_textures_node: Control = $move_marker_textures
@onready var input_control_node: Control = $input_control


func _ready() -> void:
	move_animation_finished.connect(_on_move_animation_finished)


func config(new_config_data: Dictionary[String, Variant]) -> void:
	player_color = new_config_data["player_color"]
	game_mode = new_config_data["game_mode"]
	connection_type = new_config_data["connection_type"]
	
	if game_mode != Enums.GameMode.KING_OF_THE_HILL:
		$king_of_the_hill_coloring.queue_free()
	
	if game_mode != Enums.GameMode.RACING_KINGS:
		$racing_kings_coloring.queue_free()
	
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
			var rust_piece: Enums.PieceRole = master_scene.get_piece_role_from_square(square)
			var godot_piece_node: TextureRect = piece_nodes_on_board[square]
			
			if rust_piece == Enums.PieceRole.EMPTY:
				if godot_piece_node != null:
					piece_nodes_on_board[square] = null
					godot_piece_node.queue_free()
			else:
				var piece_color: Enums.ChessColor = master_scene.get_piece_color_from_square(square)
				if godot_piece_node == null:
					var new_piece: TextureRect = new_piece_node(rust_piece, piece_color, square)
					piece_nodes_on_board[square] = new_piece
					piece_textures_node.add_child(new_piece)
				else:
					godot_piece_node.texture = PIECE_TEXTURES[ Vector2i(rust_piece, piece_color) ]


func new_piece_node(role: Enums.PieceRole, piece_color: Enums.ChessColor, square: String) -> TextureRect:
	var new_node: TextureRect = TextureRect.new()
	new_node.size = Vector2(16.0, 32.0)
	new_node.offset_transform_enabled = true
	new_node.offset_transform_position.y = -19
	new_node.position = square_to_position(square)
	new_node.texture = PIECE_TEXTURES[ Vector2i(role, piece_color) ]
	return new_node


func is_move_animation_playing() -> bool:
	return _is_move_animation_playing


func _on_input_conrol_gui_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		if event is InputEventMouseMotion:
			hovering_on_board_event( position_to_square(event.position) )
		if event is InputEventMouseButton:
			if event.is_pressed() and event.button_index == MouseButton.MOUSE_BUTTON_LEFT:
				square_select_event( position_to_square(event.position) )


func _on_input_conrol_mouse_exited() -> void:
	if any_piece_selected:
		return
	
	var old_marker_node: TextureRect = move_marker_textures_node.get_node_or_null(active_square)
	if old_marker_node != null:
		if active_square == king_in_danger_square:
			old_marker_node.texture = MOVE_MARKER_TEXTURES["red"]
		else:
			old_marker_node.queue_free()
	
	active_square = ""


func hovering_on_board_event(new_square: String) -> void:
	if any_piece_selected or new_square == active_square or is_move_animation_playing() or (game_mode == Enums.GameMode.CRAZY_HOUSE and selected_piece_for_put_move != Enums.PieceRole.EMPTY):
		return
	
	var old_marker_node: TextureRect = move_marker_textures_node.get_node_or_null(active_square)
	if old_marker_node != null:
		if active_square == king_in_danger_square:
			old_marker_node.texture = MOVE_MARKER_TEXTURES["red"]
		else:
			old_marker_node.queue_free()
	
	if piece_nodes_on_board[new_square] != null:
		if piece_in_this_square_is_playable(new_square):
			if new_square == king_in_danger_square:
				move_marker_textures_node.get_node(new_square).texture = MOVE_MARKER_TEXTURES["white"]
			else:
				add_move_marker(new_square, "white")
	
	active_square = new_square


func square_select_event(new_square: String) -> void:
	if is_move_animation_playing():
		return
	
	if game_mode == Enums.GameMode.CRAZY_HOUSE and selected_piece_for_put_move != Enums.PieceRole.EMPTY:
		if legal_put_moves.has(new_square):
			master_scene.apply_put_move(selected_piece_for_put_move, new_square)
			selected_piece_for_put_move = Enums.PieceRole.EMPTY
			clear_move_markers(true)
		return
	
	if !any_piece_selected:
		if piece_nodes_on_board[new_square] != null:
			var piece: Enums.PieceRole = master_scene.get_piece_role_from_square(new_square)
			if piece != Enums.PieceRole.EMPTY:
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
			clear_move_markers(false)
		else:
			# apply move if move is legal
			if legal_moves.has(new_square):
				disable_board_input()
				_is_move_animation_playing = true
				clear_move_markers(false)
				match legal_moves[new_square]:
					Enums.MoveType.NORMAL:
						master_scene.apply_normal_move(active_square, new_square)
					Enums.MoveType.EN_PASSANT:
						master_scene.apply_en_passant_move(active_square, new_square)
					Enums.MoveType.PROMOTION:
						master_scene.update_promotion_move_squares(active_square, new_square)
						apply_promotion_move(active_square, new_square)
					# apply castling move if rook's square is clicked (chess960 format)
					Enums.MoveType.CASTLING:
						master_scene.apply_castling_move(active_square, new_square)
			else:
				# also apply castling move if king's target square is clicked
				if KINGS_POSSIBLE_TARGET_SQUARES_IN_CASTLING_MOVE.has(new_square):
					var rook_from_square_in_castling_move: String = get_rook_from_square_in_castling_move(new_square)
					if legal_moves.has(rook_from_square_in_castling_move):
						if legal_moves[rook_from_square_in_castling_move] == Enums.MoveType.CASTLING:
							enable_board_input()
							_is_move_animation_playing = true
							any_piece_selected = false
							clear_move_markers(false)
							master_scene.apply_castling_move(active_square, rook_from_square_in_castling_move)
							return
				
				# switch selection if clicked square contains a piece and piece's owner is current player
				if piece_nodes_on_board[new_square] != null:
					var piece: Enums.PieceRole = master_scene.get_piece_role_from_square(new_square)
					if piece != Enums.PieceRole.EMPTY:
						if piece_in_this_square_is_playable(new_square):
							Sound.select.play()
							active_square = new_square
							legal_moves = master_scene.get_legal_moves_from_square(new_square)
							clear_move_markers(false)
							add_legal_move_markers()
							add_move_marker(new_square, "white")


func _on_piece_selected_for_put_move(piece_role: Enums.PieceRole) -> void:
	selected_piece_for_put_move = piece_role
	clear_move_markers(true)
	legal_put_moves = master_scene.get_legal_put_moves_from_role(piece_role)
	add_legal_put_move_markers()


func _on_piece_unselected_for_put_move() -> void:
	selected_piece_for_put_move = Enums.PieceRole.EMPTY
	clear_move_markers(false)


func get_rook_from_square_in_castling_move(king_target_square: String) -> String:
	if game_mode == Enums.GameMode.CHESS960:
		for letter in "hgfedcba" if king_target_square.begins_with("g") else "abcdefgh":
			var square: String = letter + king_target_square[1]
			if piece_nodes_on_board[square] != null: 
				if master_scene.get_piece_role_from_square(square) == Enums.PieceRole.ROOK:
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
	if piece_color == active_turn:
		if piece_color == player_color:
			return true
		elif connection_type == Enums.ConnectionType.LOCAL and local_opponent == Enums.LocalOpponent.HUMAN:
			return true
		else:
			return false
	else:
		return false


func _on_move_applied(move_type: Enums.MoveType, from: String, to: String) -> void:
	# move_type will never be PROMOTION or PUT, because Rust doesn't emit this signal for these types.
	# - PROMOTION: Rust emits "promotion_piece_updated" after the promotion
	#   piece is selected, instead of emitting this signal.
	# - PUT: Rust emits "put_move_applied" instead of this signal.
	
	move_animation_tween = create_tween().set_parallel(true)
	move_animation_tween.pause()
	move_animation_tween.finished.connect(move_animation_finished.emit)
	
	match move_type:
		Enums.MoveType.NORMAL:
			apply_normal_move(from, to)
		Enums.MoveType.EN_PASSANT:
			apply_en_passant_move(from, to)
		Enums.MoveType.CASTLING:
			apply_castling_move(from, to)
	
	move_animation_tween.play()


func _on_promotion_piece_updated(_from: String, to: String, role: Enums.PieceRole) -> void:
	update_promotion_piece(to, role)


func _on_put_move_applied(role: Enums.PieceRole, to: String) -> void:
	apply_put_move(role, to)


func _on_undo_last_move_applied(_double_undo: bool):
	clear_move_markers(false)
	move_animation_finished.emit()


func apply_normal_move(from_square: String, to_square: String) -> void:
	var from_piece_node: TextureRect = piece_nodes_on_board[from_square]
	piece_nodes_on_board[from_square] = null
	move_animation_tween.tween_property(from_piece_node, "position", square_to_position(to_square), MOVE_ANIMATION_DURATION)
	
	# remove enemy piece if target square contains an enemy piece
	var to_piece_node: TextureRect = piece_nodes_on_board[to_square]
	if to_piece_node == null:
		move_animation_tween.finished.connect(Sound.move.play)
		piece_nodes_on_board[to_square] = from_piece_node
	else:
		move_animation_tween.finished.connect(Sound.capture.play)
		move_animation_tween.tween_property(to_piece_node, "modulate:a", 0.0, MOVE_ANIMATION_DURATION / 2.0)
		move_animation_tween.finished.connect(to_piece_node.queue_free)
		
		if game_mode == Enums.GameMode.ATOMIC:
			piece_nodes_on_board[to_square] = null
			move_animation_tween.tween_property(from_piece_node, "modulate:a", 0.0, MOVE_ANIMATION_DURATION)
			move_animation_tween.finished.connect(from_piece_node.queue_free)
			explode_3x3_area_in_atomic_mode(to_square)
		else:
			piece_nodes_on_board[to_square] = from_piece_node


func apply_en_passant_move(pawn_from_square: String, pawn_to_square: String) -> void:
	var from_pawn_node: TextureRect = piece_nodes_on_board[pawn_from_square]
	piece_nodes_on_board[pawn_from_square] = null
	move_animation_tween.tween_property(from_pawn_node, "position", square_to_position(pawn_to_square), MOVE_ANIMATION_DURATION)
	
	if game_mode == Enums.GameMode.ATOMIC:
		move_animation_tween.tween_property(from_pawn_node, "modulate:a", 0.0, MOVE_ANIMATION_DURATION)
		move_animation_tween.finished.connect(from_pawn_node.queue_free)
		explode_3x3_area_in_atomic_mode(pawn_to_square)
	else:
		piece_nodes_on_board[pawn_to_square] = from_pawn_node
	
	# captured pawn square = moving pawn's target file + start rank 
	var captured_pawn_square: String = pawn_to_square[0] + pawn_from_square[1]
	var captured_pawn_node: TextureRect = piece_nodes_on_board[captured_pawn_square]
	piece_nodes_on_board[captured_pawn_square] = null
	
	move_animation_tween.tween_property(captured_pawn_node, "modulate:a", 0.0, MOVE_ANIMATION_DURATION / 2.0)
	move_animation_tween.finished.connect(captured_pawn_node.queue_free)
	move_animation_tween.finished.connect(Sound.capture.play)


func apply_castling_move(king_from_square: String, rook_from_square: String) -> void:
	# castling move came chess960 format, get king and rook target squares for godot
	var king_node: TextureRect = piece_nodes_on_board[king_from_square]
	var rook_node: TextureRect = piece_nodes_on_board[rook_from_square]
	piece_nodes_on_board[king_from_square] = null
	piece_nodes_on_board[rook_from_square] = null
	
	var king_to_square: String = get_king_target_square_in_castling_move(king_from_square, rook_from_square)
	var rook_to_square: String = get_rook_target_square_in_castling_move(king_from_square, rook_from_square)
	piece_nodes_on_board[king_to_square] = king_node
	piece_nodes_on_board[rook_to_square] = rook_node
	
	move_animation_tween.tween_property(king_node, "position", square_to_position(king_to_square), MOVE_ANIMATION_DURATION)
	move_animation_tween.tween_property(rook_node, "position", square_to_position(rook_to_square), MOVE_ANIMATION_DURATION)
	move_animation_tween.finished.connect(Sound.move.play)


func apply_promotion_move(pawn_from_square: String, pawn_to_square: String) -> void:
	move_animation_tween = create_tween().set_parallel(true)
	move_animation_tween.pause()
	
	var from_pawn_node: TextureRect = piece_nodes_on_board[pawn_from_square]
	piece_nodes_on_board[pawn_from_square] = null
	move_animation_tween.tween_property(from_pawn_node, "position", square_to_position(pawn_to_square), MOVE_ANIMATION_DURATION)
	
	# remove enemy piece if target square contains an enemy piece
	var to_piece_node: TextureRect = piece_nodes_on_board[pawn_to_square]
	if to_piece_node == null:
		move_animation_tween.finished.connect(Sound.move.play)
		piece_nodes_on_board[pawn_to_square] = from_pawn_node
	else:
		move_animation_tween.finished.connect(Sound.capture.play)
		move_animation_tween.tween_property(to_piece_node, "modulate:a", 0.0, MOVE_ANIMATION_DURATION / 2.0)
		move_animation_tween.finished.connect(to_piece_node.queue_free)
		
		# don't send promotion piece selection request if game mode is atomic, because our pawn captured too
		if game_mode == Enums.GameMode.ATOMIC:
			piece_nodes_on_board[pawn_to_square] = null
			move_animation_tween.tween_property(from_pawn_node, "modulate:a", 0.0, MOVE_ANIMATION_DURATION)
			move_animation_tween.finished.connect(from_pawn_node.queue_free)
			explode_3x3_area_in_atomic_mode(pawn_to_square)
		else:
			piece_nodes_on_board[pawn_to_square] = from_pawn_node
	
	if player_color == active_turn or (connection_type == Enums.ConnectionType.LOCAL and local_opponent == Enums.LocalOpponent.HUMAN):
		move_animation_tween.finished.connect(promotion_selection_required.emit)
	move_animation_tween.finished.connect(clear_animation_tween)
	
	move_animation_tween.play()


func clear_animation_tween():
	move_animation_tween = null


func update_promotion_piece(square: String, role: Enums.PieceRole) -> void:
	if move_animation_tween != null:
		await get_tree().create_timer(MOVE_ANIMATION_DURATION).timeout
	
	var color: Enums.ChessColor
	match square[1]:
		"8": color = Enums.ChessColor.WHITE
		"1": color = Enums.ChessColor.BLACK
	
	piece_nodes_on_board[square].texture = PIECE_TEXTURES[ Vector2i(role, color) ]
	move_animation_finished.emit()


func apply_put_move(role: Enums.PieceRole, square: String) -> void:
	Sound.move.play()
	
	var new_piece_node_instance: TextureRect = new_piece_node(role, active_turn, square)
	piece_nodes_on_board[square] = new_piece_node_instance
	piece_textures_node.add_child(new_piece_node_instance)
	move_animation_finished.emit()


func explode_3x3_area_in_atomic_mode(square: String) -> void:
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
		if master_scene.get_piece_role_from_square(target_square) == Enums.PieceRole.PAWN:
			continue
		
		var target_piece_node: TextureRect = piece_nodes_on_board[target_square]
		if target_piece_node != null:
			piece_nodes_on_board[target_square] = null
			move_animation_tween.tween_property(target_piece_node, "modulate:a", 0.0, MOVE_ANIMATION_DURATION / 2.0)
			move_animation_tween.finished.connect(target_piece_node.queue_free)


func _on_move_animation_finished() -> void:
	var new_king_in_danger_squre: String = master_scene.get_king_in_danger_square()
	if !king_in_danger_square.is_empty() and king_in_danger_square != new_king_in_danger_squre:
		# a king was in danger in previous move and king's not dangered in new move
		var old_king_in_danger: String = king_in_danger_square
		king_in_danger_square = ""
		var old_king_in_danger_marker_node = move_marker_textures_node.get_node_or_null(old_king_in_danger)
		if old_king_in_danger_marker_node != null:
			move_marker_textures_node.get_node(old_king_in_danger).queue_free()
	
	king_in_danger_square = new_king_in_danger_squre
	
	if !king_in_danger_square.is_empty():
		# a king in danger in new move
		add_move_marker(new_king_in_danger_squre, "red")
	
	clear_animation_tween()
	active_turn = master_scene.get_turn()
	_is_move_animation_playing = false


func disable_board_input() -> void:
	input_control_node.hide()
	any_piece_selected = false


func enable_board_input() -> void:
	input_control_node.show()


func add_legal_move_markers() -> void:
	if active_square == king_in_danger_square:
		move_marker_textures_node.get_node(active_square).texture = MOVE_MARKER_TEXTURES["white"]
	else:
		if move_marker_textures_node.get_node_or_null(active_square) == null:
			add_move_marker(active_square, "white")
	
	for legal_move_square: String in legal_moves.keys():
		var move_type: Enums.MoveType = legal_moves[legal_move_square] as Enums.MoveType
		var piece: Enums.PieceRole = Enums.PieceRole.EMPTY if piece_nodes_on_board[legal_move_square] == null else master_scene.get_piece_role_from_square(legal_move_square)
		
		if move_type == Enums.MoveType.CASTLING:
			add_move_marker(legal_move_square, "yellow")
			var king_target_square: String = get_king_target_square_in_castling_move(active_square, legal_move_square)
			
			if king_target_square != active_square and !legal_moves.has(king_target_square):
				add_move_marker(king_target_square, "yellow")
		elif move_type ==  Enums.MoveType.EN_PASSANT or move_type == Enums.MoveType.PROMOTION:
			add_move_marker(legal_move_square, "yellow")
		elif piece == Enums.PieceRole.EMPTY:
			add_move_marker(legal_move_square, "green")
		else:
			add_move_marker(legal_move_square, "red")


func add_legal_put_move_markers() -> void:
	for legal_put_move in legal_put_moves:
		add_move_marker(legal_put_move, "green")


func add_move_marker(square: String, color: String) -> void:
	var new_node: TextureRect = TextureRect.new()
	new_node.name = square
	new_node.size = Vector2(16.0, 16.0)
	new_node.position = square_to_position(square)
	new_node.texture = MOVE_MARKER_TEXTURES[color]
	move_marker_textures_node.add_child(new_node)


func clear_move_markers(delete_selected_piece_marker_too: bool) -> void:
	for child: TextureRect in move_marker_textures_node.get_children():
		if !is_move_animation_playing():
			if child.name == king_in_danger_square:
				if active_square != king_in_danger_square:
					child.texture = MOVE_MARKER_TEXTURES["red"]
				continue
			if child.name == active_square and !delete_selected_piece_marker_too:
				continue
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
