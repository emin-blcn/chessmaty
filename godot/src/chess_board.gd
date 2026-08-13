extends Control

signal move_animation_started(move_type: Enums.MoveType, from: String, to: String)
signal move_animation_finished(move_type: Enums.MoveType)
signal promotion_selection_required()
signal match_finished(finished_state: Enums.MatchFinishedState)

const MOVE_ANIMATION_DURATION: float = 0.4
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
const MOVE_MARKER_TEXTURES: Dictionary[String, CompressedTexture2D] = {
	"white": preload("uid://cy6eriq3qj3nw"),
	"green": preload("uid://dffcgne8d5luw"),
	"yellow": preload("uid://b1r2lw2861tk8"),
	"red": preload("uid://cwiw00cwqqit2")}
const KINGS_POSSIBLE_TARGET_SQUARES_IN_CASTLING_MOVE: PackedStringArray = ["g1", "g8", "c1", "c8"]

@onready var piece_nodes: Control = $piece_nodes
@onready var move_marker_nodes: Control = $move_marker_nodes
@onready var input_control_node: Control = $input_conrol

var chess_logic: ChessLogic = ChessLogic.new()
var active_square: String
var current_turn: Enums.ChessColor
var opponent: Enums.Opponent
var game_mode: Enums.GameMode
var player_color: Enums.ChessColor
var is_timed_game: bool
var increment_second: int
var white_time_left_second: int
var black_time_left_second: int
var ai_binary_path: String
var ai_skill_level: int
var legal_moves: Dictionary[String, int] # [String, (Enums.MoveType)]
var king_in_dangered_square: String
var promotion_pawn_from_to_square: String
var ai_selected_promotion_role: Enums.Piece
var move_animation_is_playing: bool
var any_piece_selected: bool
var board: Dictionary[String, TextureRect] = {
	"a8": null, "b8": null, "c8": null, "d8": null, "e8": null, "f8": null, "g8": null, "h8": null,
	"a7": null, "b7": null, "c7": null, "d7": null, "e7": null, "f7": null, "g7": null, "h7": null,
	"a6": null, "b6": null, "c6": null, "d6": null, "e6": null, "f6": null, "g6": null, "h6": null,
	"a5": null, "b5": null, "c5": null, "d5": null, "e5": null, "f5": null, "g5": null, "h5": null,
	"a4": null, "b4": null, "c4": null, "d4": null, "e4": null, "f4": null, "g4": null, "h4": null,
	"a3": null, "b3": null, "c3": null, "d3": null, "e3": null, "f3": null, "g3": null, "h3": null,
	"a2": null, "b2": null, "c2": null, "d2": null, "e2": null, "f2": null, "g2": null, "h2": null,
	"a1": null, "b1": null, "c1": null, "d1": null, "e1": null, "f1": null, "g1": null, "h1": null}


func _ready() -> void:
	chess_logic.move_applied.connect(_on_chess_logic_move_applied)


func initialize_board():
	chess_logic.configure_from_godot(opponent, game_mode, player_color, is_timed_game, increment_second, ai_binary_path, ai_skill_level)
	update_all_pieces()
	
	# reverse numbers and letters if player color is black
	if player_color == Enums.ChessColor.BLACK:
		for i in range(0, 8):
			$numbers_left.get_child(i).text = "12345678"[i]
			$numbers_right.get_child(i).text = "12345678"[i]
			$letters_top.get_child(i).text = "HGFEDCBA"[i]
			$letters_bottom.get_child(i).text = "HGFEDCBA"[i]
	
	if player_color == Enums.ChessColor.WHITE or opponent == Enums.Opponent.LOCAL_HUMAN:
		input_control_node.show()
	
	# AI will make first move if player color is black and opponent is AI
	elif player_color == Enums.ChessColor.BLACK and opponent == Enums.Opponent.LOCAL_AI:
		play_ai_move()


func update_all_pieces():
	# Synchronize Godot with Rust
	for number in "87654321":
		for letter in "abcdefgh":
			var square: String = letter + number
			var rust_piece: Enums.Piece = chess_logic.get_piece_from_square(square) as Enums.Piece
			var godot_piece_node: TextureRect = board[square]
			
			if rust_piece == Enums.Piece.EMPTY:
				if godot_piece_node != null:
					board[square] = null
					godot_piece_node.queue_free()
			else:
				var piece_color: Enums.ChessColor = chess_logic.get_piece_color_from_square(square) as Enums.ChessColor
				if godot_piece_node == null:
					var new_piece: TextureRect = new_piece_node(rust_piece, piece_color, square)
					board[square] = new_piece
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


func undo_last_move() -> void:
	if move_animation_is_playing or chess_logic.get_move_count() <= 0 or !chess_logic.is_undoable():
		return
	
	clear_move_markers()
	any_piece_selected = false
	
	if opponent == Enums.Opponent.LOCAL_AI:
		if chess_logic.get_move_count() == 1:
			chess_logic.undo_last_move()
			update_all_pieces()
			play_ai_move()
		else:
			chess_logic.undo_last_move()
			chess_logic.undo_last_move()
			update_all_pieces()
	else:
		chess_logic.undo_last_move()
		update_all_pieces()


func _on_input_conrol_mouse_exited() -> void:
	if any_piece_selected:
		return
	
	var old_marker_node: TextureRect = move_marker_nodes.get_node_or_null(active_square)
	if old_marker_node != null:
		if active_square == king_in_dangered_square:
			old_marker_node.texture = MOVE_MARKER_TEXTURES["red"]
		else:
			old_marker_node.queue_free()
	
	active_square = ""


func _on_input_conrol_gui_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		if event is InputEventMouseMotion:
			hovering_on_board_event( position_to_square(event.position) )
		if event is InputEventMouseButton:
			if event.is_pressed() and event.button_index == 1:
				selected_piece_event( position_to_square(event.position) )



func hovering_on_board_event(new_square: String) -> void:
	if any_piece_selected or new_square == active_square or move_animation_is_playing:
		return
	
	var old_marker_node: TextureRect = move_marker_nodes.get_node_or_null(active_square)
	if old_marker_node != null:
		if active_square == king_in_dangered_square:
			old_marker_node.texture = MOVE_MARKER_TEXTURES["red"]
		else:
			old_marker_node.queue_free()
	
	var piece: Enums.Piece = chess_logic.get_piece_from_square(new_square) as Enums.Piece
	if piece != Enums.Piece.EMPTY:
		var piece_color: Enums.ChessColor = chess_logic.get_piece_color_from_square(new_square) as Enums.ChessColor
		current_turn = chess_logic.get_turn() as Enums.ChessColor
		if piece_color == current_turn and (piece_color == player_color or opponent == Enums.Opponent.LOCAL_HUMAN):
			if new_square == king_in_dangered_square:
				move_marker_nodes.get_node(new_square).texture = MOVE_MARKER_TEXTURES["white"]
			else:
				add_move_marker(new_square, "white")
	
	active_square = new_square


func selected_piece_event(new_square: String) -> void:
	if move_animation_is_playing:
		return
	
	if !any_piece_selected:
		var piece: Enums.Piece = chess_logic.get_piece_from_square(new_square) as Enums.Piece
		if piece != Enums.Piece.EMPTY:
			var piece_color: Enums.ChessColor = chess_logic.get_piece_color_from_square(new_square) as Enums.ChessColor
			current_turn = chess_logic.get_turn() as Enums.ChessColor
			if piece_color == current_turn and (piece_color == player_color or opponent == Enums.Opponent.LOCAL_HUMAN):
				any_piece_selected = true
				active_square = new_square
				legal_moves = chess_logic.get_legal_moves_from_square(new_square)
				add_legal_move_markers()
	elif any_piece_selected:
		# cancel selection if selected piece clicked again
		if new_square == active_square:
			clear_move_markers()
			any_piece_selected = false
		else:
			if legal_moves.has(new_square):
				input_control_node.hide()
				any_piece_selected = false
				clear_move_markers()
				match legal_moves[new_square] as Enums.MoveType:
					Enums.MoveType.NORMAL:
						chess_logic.apply_normal_move(active_square, new_square)
					Enums.MoveType.EN_PASSANT:
						chess_logic.apply_en_passant_move(active_square, new_square)
					Enums.MoveType.PROMOTION:
						_on_chess_logic_move_applied(Enums.MoveType.PROMOTION_REQUEST_BY_HUMAN, active_square, new_square, Enums.Piece.EMPTY)
					Enums.MoveType.CASTLING:
						chess_logic.apply_castling_move(active_square, new_square)
			else:
				# also apply castling move if king's target square is clicked
				if KINGS_POSSIBLE_TARGET_SQUARES_IN_CASTLING_MOVE.has(new_square):
					var rook_from_square_in_castling_move: String = get_rook_from_square_in_castling_move(new_square)
					if legal_moves.has(rook_from_square_in_castling_move):
						if legal_moves[rook_from_square_in_castling_move] as Enums.MoveType == Enums.MoveType.CASTLING:
							input_control_node.hide()
							any_piece_selected = false
							clear_move_markers()
							chess_logic.apply_castling_move(active_square, rook_from_square_in_castling_move)
							return
				# switch selection if clicked square contains a piece and piece belongs to current player
				var piece: Enums.Piece = chess_logic.get_piece_from_square(new_square) as Enums.Piece
				if piece != Enums.Piece.EMPTY:
					var piece_color: Enums.ChessColor = chess_logic.get_piece_color_from_square(new_square) as Enums.ChessColor
					if piece_color == current_turn and (piece_color == player_color or opponent == Enums.Opponent.LOCAL_HUMAN):
						active_square = new_square
						legal_moves = chess_logic.get_legal_moves_from_square(new_square)
						clear_move_markers()
						add_legal_move_markers()
						add_move_marker(new_square, "white")


func get_rook_from_square_in_castling_move(king_target_square: String) -> String:
	if game_mode == Enums.GameMode.CHESS960:
		for letter in "hgfedcba" if king_target_square.begins_with("g") else "abcdefgh":
			if chess_logic.get_piece_from_square(letter + king_target_square[1]) as Enums.Piece == Enums.Piece.ROOK:
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


func _on_chess_logic_move_applied(move_type: Enums.MoveType, from: String, to: String, ai_selected_new_promotion_role: Enums.Piece):
	move_animation_started.emit(move_type, from, to)
	move_animation_is_playing = true
	
	if move_type == Enums.MoveType.UNDO or move_type == Enums.MoveType.PROMOTION:
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
			promotion_pawn_from_to_square = from + "_" + to
			apply_normal_move(from, to, tween)
		Enums.MoveType.PROMOTION_REQUEST_BY_AI:
			promotion_pawn_from_to_square = from + "_" + to
			ai_selected_promotion_role = ai_selected_new_promotion_role
			apply_normal_move(from, to, tween)
	tween.play()


func apply_normal_move(from_square: String, to_square: String, tween: Tween):
	var from_piece_node: Control = board[from_square]
	board[from_square] = null
	tween.tween_property(from_piece_node, "position", square_to_position(to_square), MOVE_ANIMATION_DURATION)
	
	# remove enemy piece if target square contains an enemy piece
	var to_piece_node: TextureRect = board[to_square]
	if to_piece_node != null:
		tween.tween_property(to_piece_node, "modulate:a", 0.0, MOVE_ANIMATION_DURATION / 2.0)
		tween.finished.connect(to_piece_node.queue_free)
	
	board[to_square] = from_piece_node


func apply_en_passant_move(pawn_from_square: String, pawn_to_square: String, tween: Tween):
	var pawn_node: Control = board[pawn_from_square]
	board[pawn_from_square] = null
	board[pawn_to_square] = pawn_node
	tween.tween_property(pawn_node, "position", square_to_position(pawn_to_square), MOVE_ANIMATION_DURATION)
	
	# captured pawn square = moving pawn's target file + start rank 
	var captured_pawn_square: String = pawn_to_square[0] + pawn_from_square[1]
	var captured_pawn_node: TextureRect = board[captured_pawn_square]
	board[captured_pawn_square] = null
	tween.tween_property(captured_pawn_node, "modulate:a", 0.0, MOVE_ANIMATION_DURATION / 2.0)
	tween.finished.connect(captured_pawn_node.queue_free)


func apply_castling_move(king_from_square: String, rook_from_square: String, tween: Tween):
	# rok hamlesi chess960 formatında geldi, godot için şahın ve kalenin hedef karesini tespit ediyoruz
	var king_node: TextureRect = board[king_from_square]
	var rook_node: TextureRect = board[rook_from_square]
	board[king_from_square] = null
	board[rook_from_square] = null
	
	var king_to_square: String = get_king_target_square_in_castling_move(king_from_square, rook_from_square)
	var rook_to_square: String = get_rook_target_square_in_castling_move(king_from_square, rook_from_square)
	board[king_to_square] = king_node
	board[rook_to_square] = rook_node
	
	tween.tween_property(king_node, "position", square_to_position(king_to_square), MOVE_ANIMATION_DURATION)
	tween.tween_property(rook_node, "position", square_to_position(rook_to_square), MOVE_ANIMATION_DURATION)


func apply_promotion_move(new_role: Enums.Piece):
	# promosyon hamlesi godot tarafında yapıldı ve animasyon oynatıldı, şimdi onu shakmaty'de de işliyoruz
	# chess_logic.apply_promotion_move() fonksiyonu, "chess_logic.move_applied()" sinyalini tetiklemeyecek
	var array: PackedStringArray = promotion_pawn_from_to_square.split("_")
	promotion_pawn_from_to_square = ""
	
	current_turn = chess_logic.get_turn() as Enums.ChessColor
	var to_square: String = array[1]
	var color: Enums.ChessColor = Enums.ChessColor.WHITE if current_turn == Enums.ChessColor.WHITE else Enums.ChessColor.BLACK
	board[to_square].texture = PIECE_TEXTURES[ [new_role, color] ]
	
	var from_square: String = array[0]
	chess_logic.apply_promotion_move(from_square, to_square, new_role)


func _on_move_animation_tween_finished(move_type: Enums.MoveType):
	current_turn = chess_logic.get_turn() as Enums.ChessColor
	move_animation_finished.emit(move_type)
	
	if opponent == Enums.Opponent.LOCAL_HUMAN:
		move_animation_is_playing = false
	elif opponent == Enums.Opponent.LOCAL_AI:
		current_turn = chess_logic.get_turn() as Enums.ChessColor
		if player_color == current_turn:
			move_animation_is_playing = false
	else:
		move_animation_is_playing = false
	
	if move_type == Enums.MoveType.PROMOTION_REQUEST_BY_HUMAN:
		# biten hamle animasyonu promosyon hamlesi ve insan tarafından yapıldı, üst sahneden promosyon taş seçimi istiyoruz
		# seçim yapıldığında apply_promotion_move() fonksiyonunu üst sahne çağıracak
		promotion_selection_required.emit()
	elif move_type == Enums.MoveType.PROMOTION_REQUEST_BY_AI:
		# biten hamle animasyonu promosyon hamlesi ve AI tarafından yapıldı
		apply_promotion_move(ai_selected_promotion_role)
		ai_selected_promotion_role = Enums.Piece.EMPTY
	
	var new_king_in_dangered_squre: String = chess_logic.get_king_in_dangered_square()
	if !king_in_dangered_square.is_empty() and king_in_dangered_square != new_king_in_dangered_squre:
		# önceki hamlede tehlikede olan bir şah vardı ve yeni hamlede tehlike geçti
		var old_king_in_danger: String = king_in_dangered_square
		king_in_dangered_square = ""
		var old_king_in_danger_marker_node = move_marker_nodes.get_node_or_null(old_king_in_danger)
		if old_king_in_danger_marker_node != null:
			move_marker_nodes.get_node(old_king_in_danger).queue_free()
	
	king_in_dangered_square = new_king_in_dangered_squre
	
	if !king_in_dangered_square.is_empty():
		# yeni hamlede tehlikede bir şah var
		add_move_marker(new_king_in_dangered_squre, "red")
	
	if move_type == Enums.MoveType.UNDO:
		input_control_node.show()
		return
	
	var match_finish_state: Enums.MatchFinishedState = chess_logic.get_match_finished_state() as Enums.MatchFinishedState
	if match_finish_state != Enums.MatchFinishedState.NOT_FINISHED:
		# maç bitti
		match_finished.emit(match_finish_state)
		return
	
	if opponent == Enums.Opponent.LOCAL_HUMAN:
		# rakip yerel insan, sıranın kimde oluduğu fark etmeksizin hamle yapmaya izin veriyoruz
		input_control_node.show()
	else:
		# rakip AI
		current_turn = chess_logic.get_turn() as Enums.ChessColor
		if player_color == current_turn:
			# sıra insanda, hamle yapmaya izin veriyoruz
			input_control_node.show()
		else:
			# sıra AI'da, insanın hamle yapmasına izin vermiyoruz ve AI'a hamle yaptırıyoruz
			play_ai_move()


func play_ai_move():
	WorkerThreadPool.add_task(
		func():
			var best_ai_move: String = chess_logic.get_best_ai_move(white_time_left_second, black_time_left_second)
			chess_logic.call_deferred("play_ai_move", best_ai_move)
	)


func add_legal_move_markers():
	if active_square == king_in_dangered_square:
		move_marker_nodes.get_node(active_square).texture = MOVE_MARKER_TEXTURES["white"]
	else:
		if move_marker_nodes.get_node_or_null(active_square) == null:
			add_move_marker(active_square, "white")
	
	for legal_move_square: String in legal_moves.keys():
		var piece: Enums.Piece = chess_logic.get_piece_from_square(legal_move_square) as Enums.Piece
		var move_type: Enums.MoveType = legal_moves[legal_move_square] as Enums.MoveType
		
		if move_type == Enums.MoveType.CASTLING:
			add_move_marker(legal_move_square, "yellow")
			var king_target_square: String = get_king_target_square_in_castling_move(active_square, legal_move_square)
			
			if king_target_square != active_square and !legal_moves.has(king_target_square):
				add_move_marker(king_target_square, "yellow")
		elif move_type ==  Enums.MoveType.EN_PASSANT or move_type == Enums.MoveType.PROMOTION:
			add_move_marker(legal_move_square, "yellow")
		elif piece == Enums.Piece.EMPTY:
			add_move_marker(legal_move_square, "green")
		else:
			add_move_marker(legal_move_square, "red")


func add_move_marker(square: String, color: String) -> void:
	var new_node: TextureRect = TextureRect.new()
	new_node.name = square
	new_node.size = Vector2(16.0, 16.0)
	new_node.position = square_to_position(square)
	new_node.texture = MOVE_MARKER_TEXTURES[color]
	move_marker_nodes.add_child(new_node)


func clear_move_markers() -> void:
	for child: TextureRect in move_marker_nodes.get_children():
		if !king_in_dangered_square.is_empty() and child.name == king_in_dangered_square:
			child.texture = MOVE_MARKER_TEXTURES["red"]
		else:
			child.queue_free()


func position_to_square(input_position: Vector2) -> String:
	var square_vector: Vector2i = input_position.clamp(Vector2.ZERO, Vector2(127.0, 127.0)) / 16.0
	var letters: String = "abcdefgh" if player_color == Enums.ChessColor.WHITE else "hgfedcba"
	var numbers: String = "87654321" if player_color == Enums.ChessColor.WHITE else "12345678"
	return letters[square_vector.x] + numbers[square_vector.y]


func square_to_position(square: String) -> Vector2:
	var letters: String = "abcdefgh" if player_color == Enums.ChessColor.WHITE else "hgfedcba"
	var numbers: String = "87654321" if player_color == Enums.ChessColor.WHITE else "12345678"
	return Vector2(letters.find(square[0]) * 16.0, numbers.find(square[1]) * 16.0)
