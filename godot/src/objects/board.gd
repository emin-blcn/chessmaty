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
const CASTLING_MOVE_KINGS_TARGET_SQUARES: Dictionary[Enums.ChessColor, PackedStringArray] = {
	Enums.ChessColor.WHITE: ["c1", "g1"],
	Enums.ChessColor.BLACK: ["c8", "g8"]}

var player_color: Enums.ChessColor
var game_mode: Enums.GameMode
var connection_type: Enums.ConnectionType
var local_opponent: Enums.LocalOpponent
var active_square: String
var any_piece_selected: bool
var legal_moves: Dictionary[String, Enums.MoveType]
var legal_put_moves: PackedStringArray
var king_in_danger_square: String
var move_animation_tween: Tween
var is_move_animation_playing: bool
var selected_put_piece_role: Enums.PieceRole = Enums.PieceRole.EMPTY
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


func setup(data: Dictionary[String, Variant]) -> void:
	player_color = data.get("player_color")
	game_mode = data.get("game_mode")
	connection_type = data.get("connection_type")
	if connection_type == Enums.ConnectionType.LOCAL:
		local_opponent = data.get("local_opponent")

	if game_mode != Enums.GameMode.KING_OF_THE_HILL:
		$king_of_the_hill_coloring.queue_free()

	if game_mode != Enums.GameMode.RACING_KINGS:
		$racing_kings_coloring.queue_free()

	if player_color == Enums.ChessColor.WHITE or (connection_type == Enums.ConnectionType.LOCAL and local_opponent == Enums.LocalOpponent.HUMAN):
		enable_board_input()

	# reverse numbers and letters if player color is black (and game mode is not "Racing Kings")
	if player_color == Enums.ChessColor.BLACK and game_mode != Enums.GameMode.RACING_KINGS:
		for i in range(0, 8):
			$numbers_left.get_child(i).text = "12345678"[i]
			$numbers_right.get_child(i).text = "12345678"[i]
			$letters_top.get_child(i).text = "HGFEDCBA"[i]
			$letters_bottom.get_child(i).text = "HGFEDCBA"[i]

	update_all_pieces()


func update_all_pieces() -> void:
	# synchronize Godot all board with Rust
	var active_board_fen: String = ""
	for fen_char in master_scene.get_active_board_fen():
		match fen_char:
			"/": continue
			"1": active_board_fen += " "
			"2": active_board_fen += "  "
			"3": active_board_fen += "   "
			"4": active_board_fen += "    "
			"5": active_board_fen += "     "
			"6": active_board_fen += "      "
			"7": active_board_fen += "       "
			"8": active_board_fen += "        "
			_: active_board_fen += fen_char

	var loop_index: int = -1
	for number in "87654321":
		for letter in "abcdefgh":
			loop_index += 1

			var piece_role: Enums.PieceRole = Enums.PieceRole.EMPTY
			match active_board_fen[loop_index].to_lower():
				"r": piece_role = Enums.PieceRole.ROOK
				"n": piece_role = Enums.PieceRole.KNIGHT
				"b": piece_role = Enums.PieceRole.BISHOP
				"q": piece_role = Enums.PieceRole.QUEEN
				"k": piece_role = Enums.PieceRole.KING
				"p": piece_role = Enums.PieceRole.PAWN
			var piece_color: Enums.ChessColor
			match active_board_fen[loop_index]:
				"R", "N", "B", "Q", "K", "P": piece_color = Enums.ChessColor.WHITE
				"r", "n", "b", "q", "k", "p": piece_color = Enums.ChessColor.BLACK

			var square: String = letter + number
			var piece_node_on_board: TextureRect = piece_nodes_on_board.get(square)

			if piece_role == Enums.PieceRole.EMPTY:
				if piece_node_on_board != null:
					piece_nodes_on_board.set(square, null)
					piece_node_on_board.queue_free()
			else:
				if piece_node_on_board != null:
					piece_node_on_board.texture = PIECE_TEXTURES.get(Vector2i(piece_role, piece_color))
				else:
					var new_piece_node_instance: TextureRect = new_piece_node(piece_role, piece_color, square)
					piece_nodes_on_board.set(square, new_piece_node_instance)
					piece_textures_node.add_child(new_piece_node_instance)


func new_piece_node(role: Enums.PieceRole, color: Enums.ChessColor, square: String) -> TextureRect:
	var new_node: TextureRect = TextureRect.new()
	new_node.size = Vector2(16.0, 32.0)
	new_node.offset_transform_enabled = true
	new_node.offset_transform_position.y = -19
	new_node.position = square_to_position(square)
	new_node.texture = PIECE_TEXTURES.get(Vector2i(role, color))
	return new_node


func get_move_animation_playing() -> bool:
	return is_move_animation_playing


func set_move_animation_playing(value: bool) -> void:
	is_move_animation_playing = value


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
			old_marker_node.texture = MOVE_MARKER_TEXTURES.get("red")
		else:
			old_marker_node.queue_free()

	active_square = ""


func hovering_on_board_event(new_square: String) -> void:
	if (any_piece_selected
	or new_square == active_square
	or get_move_animation_playing()
	or (game_mode == Enums.GameMode.CRAZY_HOUSE and selected_put_piece_role != Enums.PieceRole.EMPTY)):
		return

	var old_marker_node: TextureRect = move_marker_textures_node.get_node_or_null(active_square)
	if old_marker_node != null:
		if active_square == king_in_danger_square:
			old_marker_node.texture = MOVE_MARKER_TEXTURES.get("red")
		else:
			old_marker_node.queue_free()

	if piece_nodes_on_board.get(new_square) != null:
		var piece_color: Enums.ChessColor = master_scene.get_piece_color_from_square(new_square)
		if piece_color == master_scene.get_active_turn():
			if new_square == king_in_danger_square:
				move_marker_textures_node.get_node(new_square).texture = MOVE_MARKER_TEXTURES.get("white")
			else:
				add_move_marker(new_square, "white")

	active_square = new_square


func square_select_event(new_square: String) -> void:
	# apply put move if move is legal
	if game_mode == Enums.GameMode.CRAZY_HOUSE and selected_put_piece_role != Enums.PieceRole.EMPTY and legal_put_moves.has(new_square):
		Sound.move.play()
		master_scene.apply_put_move(selected_put_piece_role, new_square)
		legal_put_moves.clear()
		selected_put_piece_role = Enums.PieceRole.EMPTY
		clear_move_markers()
		return

	if !any_piece_selected:
		if piece_nodes_on_board.get(new_square) != null:
			var piece_role: Enums.PieceRole = master_scene.get_piece_role_from_square(new_square)
			if piece_role != Enums.PieceRole.EMPTY:
				var piece_color: Enums.ChessColor = master_scene.get_piece_color_from_square(new_square)
				if piece_color == master_scene.get_active_turn():
					Sound.select.play()
					any_piece_selected = true
					active_square = new_square
					legal_moves = master_scene.get_legal_moves_from_square(new_square)
					add_legal_move_markers()
	else:
		# cancel selection if selected piece clicked again
		if new_square == active_square:
			clear_move_markers(true)
			legal_moves.clear()
			any_piece_selected = false
		else:
			# apply move if move is legal
			if legal_moves.has(new_square):
				disable_board_input()
				set_move_animation_playing(true)
				clear_move_markers()
				match legal_moves.get(new_square):
					Enums.MoveType.NORMAL:
						master_scene.apply_normal_move(active_square, new_square)
					Enums.MoveType.EN_PASSANT:
						master_scene.apply_en_passant_move(active_square, new_square)
					Enums.MoveType.PROMOTION:
						master_scene.update_promotion_move_squares_data(active_square, new_square)
						apply_promotion_move_and_play_animation(active_square, new_square)
					# apply castling move if rook's from square is clicked (chess960 format)
					Enums.MoveType.CASTLING:
						master_scene.apply_castling_move(active_square, new_square)
				legal_moves.clear()
			else:
				# also apply castling move if king's target square is clicked in castling move
				var chess960_format_castling_move: String = get_chess960_format_castling_move(new_square)
				if legal_moves.has(chess960_format_castling_move) and legal_moves.get(chess960_format_castling_move) == Enums.MoveType.CASTLING:
					disable_board_input()
					set_move_animation_playing(true)
					clear_move_markers()
					master_scene.apply_castling_move(active_square, chess960_format_castling_move)
					legal_moves.clear()
					return
				# switch selection if clicked square contains a piece and piece's owner is current player
				if piece_nodes_on_board.get(new_square) != null:
					var piece_role: Enums.PieceRole = master_scene.get_piece_role_from_square(new_square)
					if piece_role != Enums.PieceRole.EMPTY:
						var piece_color: Enums.ChessColor = master_scene.get_piece_color_from_square(new_square)
						if piece_color == master_scene.get_active_turn():
							Sound.select.play()
							any_piece_selected = true
							active_square = new_square
							legal_moves = master_scene.get_legal_moves_from_square(new_square)
							clear_move_markers()
							add_move_marker(new_square, "white")
							add_legal_move_markers()


func get_chess960_format_castling_move(target_square: String) -> String:
	if !CASTLING_MOVE_KINGS_TARGET_SQUARES.get(master_scene.get_active_turn()).has(target_square):
		return ""

	if master_scene.get_piece_role_from_square(active_square) != Enums.PieceRole.KING:
		return ""

	if game_mode == Enums.GameMode.CHESS960:
		var number: String = target_square[1]
		for letter in "abcdefgh" if target_square[0] == "c" else "hgfedcba":
			var square: String = letter + number
			var piece_node_on_board: TextureRect = piece_nodes_on_board.get(square)
			if piece_node_on_board != null:
				if piece_node_on_board.texture == PIECE_TEXTURES.get(Vector2i(Enums.PieceRole.ROOK, master_scene.get_active_turn())):
					return letter + number

	match target_square:
		"c1": return "a1"
		"c8": return "a8"
		"g1": return "h1"
		"g8": return "h8"
		_: return ""


func get_king_target_square_in_castling_move(king_from_square: String, rook_from_square: String) -> String:
	var is_king_side: bool = rook_from_square[0] > king_from_square[0]
	return ("g" if is_king_side else "c") + king_from_square[1]


func get_rook_target_square_in_castling_move(king_from_square: String, rook_from_square: String) -> String:
	var is_king_side: bool = rook_from_square[0] > king_from_square[0]
	return ("f" if is_king_side else "d") + king_from_square[1]


func _on_move_applied(move_type: Enums.MoveType, from: String, to: String) -> void:
	# move_type will never be PROMOTION or PUT, because Rust doesn't emit this signal for these types.
	# - PROMOTION: Rust emits "promotion_piece_updated" after the promotion
	#   piece is selected, instead of emitting this signal.
	# - PUT: Rust emits "put_move_applied" instead of this signal.

	update_king_in_danger_square()

	move_animation_tween = create_tween().set_parallel(true)
	move_animation_tween.pause()
	move_animation_tween.finished.connect(move_animation_finished.emit)

	match move_type:
		Enums.MoveType.NORMAL:
			apply_normal_move_and_play_animation(from, to)
		Enums.MoveType.EN_PASSANT:
			apply_en_passant_move_and_play_animation(from, to)
		Enums.MoveType.CASTLING:
			apply_castling_move_and_play_animation(from, to)

	move_animation_tween.play()


func apply_normal_move_and_play_animation(from_square: String, to_square: String) -> void:
	var from_piece_node: TextureRect = piece_nodes_on_board.get(from_square)
	piece_nodes_on_board.set(from_square, null)
	move_animation_tween.tween_property(from_piece_node, "position", square_to_position(to_square), MOVE_ANIMATION_DURATION)

	# remove enemy piece if target square contains an enemy piece
	var to_piece_node: TextureRect = piece_nodes_on_board.get(to_square)
	if to_piece_node == null:
		move_animation_tween.finished.connect(Sound.move.play)
		piece_nodes_on_board.set(to_square, from_piece_node)
	else:
		move_animation_tween.finished.connect(Sound.capture.play)
		move_animation_tween.tween_property(to_piece_node, "modulate:a", 0.0, MOVE_ANIMATION_DURATION / 2.0)
		move_animation_tween.finished.connect(to_piece_node.queue_free)

		if game_mode == Enums.GameMode.ATOMIC:
			piece_nodes_on_board.set(to_square, null)
			move_animation_tween.tween_property(from_piece_node, "modulate:a", 0.0, MOVE_ANIMATION_DURATION)
			move_animation_tween.finished.connect(from_piece_node.queue_free)
			explode_3x3_area_in_atomic_mode(to_square)
		else:
			piece_nodes_on_board.set(to_square, from_piece_node)


func apply_en_passant_move_and_play_animation(pawn_from_square: String, pawn_to_square: String) -> void:
	var from_pawn_node: TextureRect = piece_nodes_on_board.get(pawn_from_square)
	piece_nodes_on_board.set(pawn_from_square, null)
	move_animation_tween.tween_property(from_pawn_node, "position", square_to_position(pawn_to_square), MOVE_ANIMATION_DURATION)

	if game_mode == Enums.GameMode.ATOMIC:
		move_animation_tween.tween_property(from_pawn_node, "modulate:a", 0.0, MOVE_ANIMATION_DURATION)
		move_animation_tween.finished.connect(from_pawn_node.queue_free)
		explode_3x3_area_in_atomic_mode(pawn_to_square)
	else:
		piece_nodes_on_board.set(pawn_to_square, from_pawn_node)

	# captured pawn square = moving pawn's target file + start rank
	var captured_pawn_square: String = pawn_to_square[0] + pawn_from_square[1]
	var captured_pawn_node: TextureRect = piece_nodes_on_board.get(captured_pawn_square)
	piece_nodes_on_board.set(captured_pawn_square, null)

	move_animation_tween.tween_property(captured_pawn_node, "modulate:a", 0.0, MOVE_ANIMATION_DURATION / 2.0)
	move_animation_tween.finished.connect(captured_pawn_node.queue_free)
	move_animation_tween.finished.connect(Sound.capture.play)


func apply_castling_move_and_play_animation(king_from_square: String, rook_from_square: String) -> void:
	# castling move came chess960 format, get king and rook target squares for godot
	var king_node: TextureRect = piece_nodes_on_board.get(king_from_square)
	var rook_node: TextureRect = piece_nodes_on_board.get(rook_from_square)
	piece_nodes_on_board.set(king_from_square, null)
	piece_nodes_on_board.set(rook_from_square, null)

	var king_to_square: String = get_king_target_square_in_castling_move(king_from_square, rook_from_square)
	var rook_to_square: String = get_rook_target_square_in_castling_move(king_from_square, rook_from_square)
	piece_nodes_on_board.set(king_to_square, king_node)
	piece_nodes_on_board.set(rook_to_square, rook_node)

	move_animation_tween.tween_property(king_node, "position", square_to_position(king_to_square), MOVE_ANIMATION_DURATION)
	move_animation_tween.tween_property(rook_node, "position", square_to_position(rook_to_square), MOVE_ANIMATION_DURATION)
	move_animation_tween.finished.connect(Sound.move.play)


func apply_promotion_move_and_play_animation(pawn_from_square: String, pawn_to_square: String) -> void:
	move_animation_tween = create_tween().set_parallel(true)
	move_animation_tween.pause()

	var from_pawn_node: TextureRect = piece_nodes_on_board.get(pawn_from_square)
	piece_nodes_on_board.set(pawn_from_square, null)
	move_animation_tween.tween_property(from_pawn_node, "position", square_to_position(pawn_to_square), MOVE_ANIMATION_DURATION)

	# remove enemy piece if target square contains an enemy piece
	var to_piece_node: TextureRect = piece_nodes_on_board[pawn_to_square]
	if to_piece_node == null:
		move_animation_tween.finished.connect(Sound.move.play)
		piece_nodes_on_board.set(pawn_to_square, from_pawn_node)
	else:
		move_animation_tween.finished.connect(Sound.capture.play)
		move_animation_tween.tween_property(to_piece_node, "modulate:a", 0.0, MOVE_ANIMATION_DURATION / 2.0)
		move_animation_tween.finished.connect(to_piece_node.queue_free)

		# don't send promotion piece selection request if game mode is atomic, because our pawn captured too
		if game_mode == Enums.GameMode.ATOMIC:
			piece_nodes_on_board.set(pawn_to_square, null)
			move_animation_tween.tween_property(from_pawn_node, "modulate:a", 0.0, MOVE_ANIMATION_DURATION)
			move_animation_tween.finished.connect(from_pawn_node.queue_free)
			explode_3x3_area_in_atomic_mode(pawn_to_square)
		else:
			piece_nodes_on_board.set(pawn_to_square, from_pawn_node)

	if player_color == master_scene.get_active_turn() or (connection_type == Enums.ConnectionType.LOCAL and local_opponent == Enums.LocalOpponent.HUMAN):
		move_animation_tween.finished.connect(promotion_selection_required.emit)
	move_animation_tween.finished.connect(clear_animation_tween)

	move_animation_tween.play()


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

		var target_piece_node: TextureRect = piece_nodes_on_board.get(target_square)
		if target_piece_node != null:
			piece_nodes_on_board.set(target_square, null)
			move_animation_tween.tween_property(target_piece_node, "modulate:a", 0.0, MOVE_ANIMATION_DURATION / 2.0)
			move_animation_tween.finished.connect(target_piece_node.queue_free)


func _on_promotion_piece_updated(_from: String, to: String, role: Enums.PieceRole) -> void:
	if connection_type != Enums.ConnectionType.LOCAL and player_color == master_scene.get_active_turn():
		await get_tree().create_timer(MOVE_ANIMATION_DURATION).timeout

	var color: Enums.ChessColor
	match to[1]:
		"8": color = Enums.ChessColor.WHITE
		"1": color = Enums.ChessColor.BLACK

	piece_nodes_on_board.get(to).texture = PIECE_TEXTURES.get(Vector2i(role, color))

	update_king_in_danger_square()
	move_animation_finished.emit()


func _on_put_piece_selected(role: Enums.PieceRole) -> void:
	selected_put_piece_role = role
	legal_put_moves = master_scene.get_legal_put_moves_from_role(role)
	clear_move_markers()
	add_legal_put_move_markers()


func _on_put_piece_unselected() -> void:
	selected_put_piece_role = Enums.PieceRole.EMPTY
	clear_move_markers()


func _on_put_move_applied(role: Enums.PieceRole, to: String) -> void:
	# reverse color, because active_turn is changed in master_scene after apply_*_move functions.
	# active_turn opposite player should get a new piece.
	var color: Enums.ChessColor = Enums.ChessColor.WHITE if master_scene.get_active_turn() == Enums.ChessColor.BLACK else Enums.ChessColor.BLACK
	var new_piece_node_instance: TextureRect = new_piece_node(role, color, to)
	piece_nodes_on_board.set(to, new_piece_node_instance)
	piece_textures_node.add_child(new_piece_node_instance)

	update_king_in_danger_square()
	move_animation_finished.emit()


func _on_undo_last_move_applied(_double_undo: bool) -> void:
	clear_move_markers()
	update_all_pieces()

	update_king_in_danger_square()
	move_animation_finished.emit()


func update_king_in_danger_square():
	var new_king_in_danger_square: String = master_scene.get_king_in_danger_square()
	if new_king_in_danger_square.is_empty():
		var king_in_danger_marker_node: TextureRect = move_marker_textures_node.get_node_or_null(king_in_danger_square)
		if king_in_danger_marker_node != null:
			king_in_danger_marker_node.queue_free()

	king_in_danger_square = new_king_in_danger_square


func _on_move_animation_finished() -> void:
	# add red marker if a king in danger in new move
	if !king_in_danger_square.is_empty():
		add_move_marker(king_in_danger_square, "red")

	any_piece_selected = false
	clear_animation_tween()

	if player_color == master_scene.get_active_turn() or (connection_type == Enums.ConnectionType.LOCAL and local_opponent == Enums.LocalOpponent.HUMAN):
		enable_board_input()


func clear_animation_tween():
	move_animation_tween = null
	set_move_animation_playing(false)


func disable_board_input() -> void:
	input_control_node.hide()


func enable_board_input() -> void:
	input_control_node.show()


func add_legal_move_markers() -> void:
	if active_square == king_in_danger_square:
		move_marker_textures_node.get_node(active_square).texture = MOVE_MARKER_TEXTURES.get("white")
	else:
		if move_marker_textures_node.get_node_or_null(active_square) == null:
			add_move_marker(active_square, "white")

	for legal_move_square: String in legal_moves.keys():
		var move_type: Enums.MoveType = legal_moves.get(legal_move_square)
		var piece: Enums.PieceRole = Enums.PieceRole.EMPTY if piece_nodes_on_board.get(legal_move_square) == null else master_scene.get_piece_role_from_square(legal_move_square)

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
	new_node.texture = MOVE_MARKER_TEXTURES.get(color)
	move_marker_textures_node.add_child(new_node)


func clear_move_markers(keep_selected_piece_marker: bool = false) -> void:
	for child: TextureRect in move_marker_textures_node.get_children():
		if child.name == king_in_danger_square:
			if active_square != king_in_danger_square:
				child.texture = MOVE_MARKER_TEXTURES.get("red")
			continue
		elif keep_selected_piece_marker and child.name == active_square:
			continue
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
