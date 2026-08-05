extends Control

signal move_animation_started(move_type: String)
signal move_animation_finished(move_type: String)
signal promotion_selection_required()
signal match_finished(winner: String)

const MOVE_ANIMATION_DURATION: float = 0.4
const PIECE_TEXTURES: Dictionary[String, Resource] = {
	"King_white": preload("uid://cags18jbwmm0d"),
	"King_black": preload("uid://dioyjnoc4d7vu"),
	"Queen_white": preload("uid://cfi88xmcwl8xv"),
	"Queen_black": preload("uid://cp7h3f6nl280m"),
	"Bishop_white": preload("uid://cnkaj6a1nvawt"),
	"Bishop_black": preload("uid://dnip4r75iln63"),
	"Knight_white": preload("uid://bb6wpbdxlg4jl"),
	"Knight_black": preload("uid://b1qiry1fgwq7y"),
	"Rook_white": preload("uid://b43npdubwnbj"),
	"Rook_black": preload("uid://cdw8mxfjy7wn3"),
	"Pawn_white": preload("uid://dcolfenoo2rm8"),
	"Pawn_black": preload("uid://ccn6a7hxwydu")}
const MOVE_MARKER_TEXTURES: Dictionary[String, CompressedTexture2D] = {
	"white": preload("uid://cy6eriq3qj3nw"),
	"green": preload("uid://dffcgne8d5luw"),
	"yellow": preload("uid://b1r2lw2861tk8"),
	"red": preload("uid://cwiw00cwqqit2")}

@onready var piece_nodes: Control = $piece_nodes
@onready var move_marker_nodes: Control = $move_marker_nodes
@onready var input_conrol_node: Control = $input_conrol

var chess_logic: ChessLogic = ChessLogic.new()
var active_square: String
var opponent: Enums.Opponent
var game_mode: Enums.GameMode
var player_color: Enums.ChessColor
var ai_binary_path: String
var legal_moves: PackedStringArray
var king_in_dangered_square: String
var promotion_pawn_from_to_square: String
var ai_selected_promotion_role: String
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
	var board_fen_string: String = chess_logic.configure_from_godot_and_get_board_fen(opponent, game_mode, player_color, 518, ai_binary_path)
	
	board_fen_string = board_fen_string.replace("/", "").replace("8", "        ").replace("7", "       ").replace("6", "      ").replace("5", "     ").replace("4", "    ").replace("3", "   ").replace("2", "  ").replace("1", " ")
	
	var index: int = 0
	
	for number in "87654321":
		for letter in "abcdefgh":
			if board_fen_string[index] != " ":
				var square: String = letter + number
				board[square] = get_new_piece_and_add_scene(board_fen_string[index], square)
			index += 1
	
	if player_color == Enums.ChessColor.BLACK:
		for i in range(0, 8):
			$numbers_left.get_child(i).text = "12345678"[i]
			$numbers_right.get_child(i).text = "12345678"[i]
			$letters_top.get_child(i).text = "HGFEDCBA"[i]
			$letters_bottom.get_child(i).text = "HGFEDCBA"[i]
	
	if player_color == Enums.ChessColor.BLACK and opponent == Enums.Opponent.LOCAL_AI:
		# oyuncu siyah ve rakip AI, ilk hamleyi AI yapacak
		play_ai_move()


func get_new_piece_and_add_scene(piece_char: String, square: String) -> TextureRect:
	var new_node: TextureRect = TextureRect.new()
	
	new_node.size = Vector2(16.0, 32.0)
	new_node.offset_transform_enabled = true
	new_node.offset_transform_position.y = -19
	new_node.position = square_to_position(square)
	
	var piece_texture: CompressedTexture2D
	
	match piece_char:
		"K": piece_texture = PIECE_TEXTURES["King_white"]
		"k": piece_texture = PIECE_TEXTURES["King_black"]
		"Q": piece_texture = PIECE_TEXTURES["Queen_white"]
		"q": piece_texture = PIECE_TEXTURES["Queen_black"]
		"B": piece_texture = PIECE_TEXTURES["Bishop_white"]
		"b": piece_texture = PIECE_TEXTURES["Bishop_black"]
		"N": piece_texture = PIECE_TEXTURES["Knight_white"]
		"n": piece_texture = PIECE_TEXTURES["Knight_black"]
		"R": piece_texture = PIECE_TEXTURES["Rook_white"]
		"r": piece_texture = PIECE_TEXTURES["Rook_black"]
		"P": piece_texture = PIECE_TEXTURES["Pawn_white"]
		"p": piece_texture = PIECE_TEXTURES["Pawn_black"]
	new_node.texture = piece_texture
	
	piece_nodes.add_child(new_node)
	return new_node


func _on_input_conrol_mouse_exited() -> void:
	# imleç tahtadan dışarı çıktı
	if any_piece_selected:
		# bir taş seçili
		return
	
	var old_marker_node: TextureRect = move_marker_nodes.get_node_or_null(active_square)
	
	if old_marker_node != null:
		if active_square == king_in_dangered_square:
			old_marker_node.texture = MOVE_MARKER_TEXTURES["red"]
		else:
			old_marker_node.queue_free()
	
	active_square = ""


func _on_input_conrol_gui_input(event: InputEvent) -> void:
	# imleç tahta içinde
	if event is InputEventMouse:
		if event is InputEventMouseMotion:
			# imleç tahta üzerinde kaydırılıyor
			hovering_on_board_event( position_to_square(event.position) )
		
		if event is InputEventMouseButton:
			if event.is_pressed() and event.button_index == 1:
				# sol fare tuşu bir kere tıklandı
				selected_piece_event( position_to_square(event.position) )


func hovering_on_board_event(new_square: String) -> void:
	# fare tahta üzerinde kayıyor
	if any_piece_selected or new_square == active_square:
		# bir taş seçili ya da fare hala aynı kareden dışarı çıkmadı
		return
	
	var old_marker_node: TextureRect = move_marker_nodes.get_node_or_null(active_square)
	
	if old_marker_node != null:
		# farenin geçtiği önceki karede marker node var (yani kare yasal hamelerden biri ya da hedefteki şahın karesi)
		if active_square == king_in_dangered_square:
			# farenin geçtiği önceki karede tehlikede olan bir şah var
			old_marker_node.texture = MOVE_MARKER_TEXTURES["red"]
		else:
			# farenin geçtiği önceki karede tehlikede olan bir şah yok
			old_marker_node.queue_free()
	
	var piece: String = chess_logic.get_piece_from_square(new_square)
	
	if piece != "empty":
		# fare bir taşın üzerine geldi
		var piece_color: Enums.ChessColor = Enums.ChessColor.WHITE if piece.split("_")[1] == "white" else Enums.ChessColor.BLACK
		
		if piece_color == chess_logic.get_turn() and (piece_color == player_color or opponent == Enums.Opponent.LOCAL_HUMAN):
			# fare bir taşın üzerine geldi ve taş sırası olan oyuncuya ait (ya da rakip yerel insan)
			if new_square == king_in_dangered_square:
				move_marker_nodes.get_node(new_square).texture = MOVE_MARKER_TEXTURES["white"]
			else:
				add_move_marker(new_square, "white")
	
	active_square = new_square


func selected_piece_event(new_square: String) -> void:
	# fare tahta üzerinde bir kere tıklandı
	if !any_piece_selected:
		# hiçbir taş seçili değilken, fare bir kere tıklandı
		var piece = chess_logic.get_piece_from_square(new_square)
		if piece != "empty":
			# hiçbir taş seçili değilken, bir taşa tıklandı
			var piece_color: Enums.ChessColor = Enums.ChessColor.WHITE if piece.split("_")[1] == "white" else Enums.ChessColor.BLACK
		
			if piece_color == chess_logic.get_turn() and (piece_color == player_color or opponent == Enums.Opponent.LOCAL_HUMAN):
				# hiçbir taş seçili değilken bir taşa tıklandı, taş sırası olan oyuncuya ait (ya da rakip yerel insan)
				any_piece_selected = true
				active_square = new_square
				legal_moves = chess_logic.get_legal_moves_from_square(new_square)
				add_legal_move_markers()
				if new_square == king_in_dangered_square:
					# tehlikede olan şah seçildi, onun karesinde zaten beyaz marker var, bu yüzden onu kırmızıya çeviriyoruz
					move_marker_nodes.get_node(new_square).texture = MOVE_MARKER_TEXTURES["white"]
				else:
					# tehlikede olan şah değil, herhangi bir taş seçildi (tehlikede olmayan şah da olabilir)
					# halihazırda marker var mı, kontrol ediyoruz (fare kayarken eklenen marker var olabilir)
					var white_move_marker_node: TextureRect = move_marker_nodes.get_node_or_null(new_square)
					if white_move_marker_node == null:
						# halihazırda marker yok
						add_move_marker(new_square, "white")
	elif any_piece_selected:
		# bir taş seçiliyken, fare bir kere tıklandı
		if active_square == new_square:
			# bir taş seçiliyken, aynı taş tekrar tıklandı
			clear_move_markers()
			any_piece_selected = false
		else:
			# bir taş seçiliyken, farklı bir kare tıklandı
			if legal_moves.has("n_" + new_square):
				# normal hamle
				input_conrol_node.hide()
				any_piece_selected = false
				clear_move_markers()
				chess_logic.apply_normal_move(active_square, new_square)
			elif legal_moves.has("e_" + new_square):
				# geçerken alma hamlesi
				input_conrol_node.hide()
				any_piece_selected = false
				clear_move_markers()
				chess_logic.apply_en_passant_move(active_square, new_square)
			elif legal_moves.has("p_" + new_square):
				# promosyon hamlesi
				input_conrol_node.hide()
				any_piece_selected = false
				clear_move_markers()
				_on_chess_logic_move_applied("promotion_request", active_square, new_square, "")
			else:
				var rook_square: String = get_rook_square(active_square, new_square)
				
				if !rook_square.is_empty():
					# rok hamlesi
					input_conrol_node.hide()
					any_piece_selected = false
					clear_move_markers()
					chess_logic.apply_rook_move(active_square, rook_square)
				else:
					# hamle yasal değil
					var piece = chess_logic.get_piece_from_square(new_square)
					if piece != "empty":
						# bir taş seçiliyken, farklı bir taşa tıklandı
						var piece_color: Enums.ChessColor = Enums.ChessColor.WHITE if piece.split("_")[1] == "white" else Enums.ChessColor.BLACK
						
						if piece_color == chess_logic.get_turn() and (piece_color == player_color or opponent == Enums.Opponent.LOCAL_HUMAN):
							# bir taş seçiliyken sırası olan oyuncuya ait başka bir taşa tıklandı (ya da rakip yerel insan)
							active_square = new_square
							legal_moves = chess_logic.get_legal_moves_from_square(new_square)
							clear_move_markers()
							add_legal_move_markers()
							add_move_marker(new_square, "white")


func get_rook_square(from_square: String, to_square: String) -> String:
	if legal_moves.has("r_" + to_square):
		# rok hamlesinde hedef olarak kaleye tıklandı, olduğu gibi kale karesini veriyoruz
		return to_square
	
	for legal_move: String in legal_moves:
		if legal_move.begins_with("r_"):
			# rok hamlesinde hedef olarak şahın gideceği kare tıklandı, shakmaty için onu kale karesine çeviriyoruz
			var rook_square: String = legal_move.substr(2)
			if to_square == get_king_target_square_in_rook_move(from_square, rook_square):
				return rook_square
	
	return ""


func get_king_target_square_in_rook_move(king_from_square: String, rook_from_square: String) -> String:
	var is_king_side: bool = rook_from_square[0] > king_from_square[0]
	return ("g" if is_king_side else "c") + king_from_square[1]


func get_rook_target_square_in_rook_move(king_from_square: String, rook_from_square: String) -> String:
	var is_king_side: bool = rook_from_square[0] > king_from_square[0]
	return ("f" if is_king_side else "d") + king_from_square[1]


func _on_chess_logic_move_applied(move_type: String, from: String, to: String, ai_selected_new_promotion_role: String):
	var tween: Tween = create_tween().set_parallel(true)
	tween.pause()
	tween.finished.connect(_on_move_animation_tween_finished.bind(move_type))
	
	match move_type:
		"normal":
			apply_normal_move(from, to, tween)
		"en_passant":
			apply_en_passant_move(from, to, tween)
		"rook":
			apply_rook_move(from, to, tween)
		"promotion_request":
			promotion_pawn_from_to_square = from + "_" + to
			apply_normal_move(from, to, tween)
		"promotion_by_ai":
			ai_selected_promotion_role = ai_selected_new_promotion_role
			promotion_pawn_from_to_square = from + "_" + to
			apply_normal_move(from, to, tween)
	
	tween.play()
	move_animation_started.emit(move_type)


func apply_normal_move(from_square: String, to_square: String, tween: Tween):
	var from_piece_node: Control = board[from_square]
	board[from_square] = null
	tween.tween_property(from_piece_node, "position", square_to_position(to_square), MOVE_ANIMATION_DURATION)
	
	var to_piece_node: TextureRect = board[to_square]
	
	if to_piece_node != null:
		# hedef karede düşman taş var
		board[to_square] = null
		tween.tween_property(to_piece_node, "modulate:a", 0.0, MOVE_ANIMATION_DURATION / 2.0)
		tween.finished.connect(to_piece_node.queue_free)
	
	board[to_square] = from_piece_node


func apply_en_passant_move(pawn_from_square: String, pawn_to_square: String, tween: Tween):
	var pawn_node: Control = board[pawn_from_square]
	board[pawn_from_square] = null
	board[pawn_to_square] = pawn_node
	tween.tween_property(pawn_node, "position", square_to_position(pawn_to_square), MOVE_ANIMATION_DURATION)
	
	var target_pawn_square: String = pawn_to_square[0] + pawn_from_square[1] # hamle yapan piyonun, hedef karesinin harfi + başlangıç karesinin numarası = yenilecek piyonun olduğu kare.
	var target_pawn_node: TextureRect = board[target_pawn_square]
	board[target_pawn_square] = null
	
	tween.tween_property(target_pawn_node, "modulate:a", 0.0, MOVE_ANIMATION_DURATION / 2.0)
	tween.finished.connect(target_pawn_node.queue_free)


func apply_rook_move(king_from_square: String, rook_from_square: String, tween: Tween):
	# rok hamlesi chess960 formatında geldi, godot için şahın ve kalenin hedef karesini tespit ediyoruz
	
	var king_node: TextureRect = board[king_from_square]
	var rook_node: TextureRect = board[rook_from_square]
	
	var king_to_square: String = get_king_target_square_in_rook_move(king_from_square, rook_from_square)
	var rook_to_square: String = get_rook_target_square_in_rook_move(king_from_square, rook_from_square)
	
	board[king_from_square] = null
	board[rook_from_square] = null
	
	board[king_to_square] = king_node
	board[rook_to_square] = rook_node
	
	tween.tween_property(king_node, "position", square_to_position(king_to_square), MOVE_ANIMATION_DURATION)
	tween.tween_property(rook_node, "position", square_to_position(rook_to_square), MOVE_ANIMATION_DURATION)


func apply_promotion_move(new_role: String):
	# promosyon hamlesi godot tarafında yapıldı ve animasyon oynatıldı, şimdi onu shakmaty'de de işliyoruz
	# chess_logic.apply_promotion_move() fonksiyonu, "chess_logic.move_applied()" sinyalini tetiklemeyecek
	var array: PackedStringArray = promotion_pawn_from_to_square.split("_")
	promotion_pawn_from_to_square = ""
	
	var from_square: String = array[0]
	var to_square: String = array[1]
	var color: String = "white" if chess_logic.get_turn() == Enums.ChessColor.WHITE else "black"
	
	board[to_square].texture = PIECE_TEXTURES[new_role + "_" + color]
	
	chess_logic.apply_promotion_move(from_square, to_square, new_role)


func _on_move_animation_tween_finished(move_type: String):
	# hamle animasyonu bitti
	move_animation_finished.emit(move_type)
	
	if move_type == "promotion_request":
		# biten hamle animasyonu promosyon hamlesi ve insan tarafından yapıldı, üst sahneden promosyon taş seçimi istiyoruz
		# seçim yapıldığında apply_promotion_move() fonksiyonunu üst sahne çağıracak
		promotion_selection_required.emit()
	
	elif move_type == "promotion_by_ai":
		# biten hamle animasyonu promosyon hamlesi ve AI tarafından yapıldı
		apply_promotion_move(ai_selected_promotion_role)
		ai_selected_promotion_role = ""
	
	var new_king_in_dangered_squre: String = chess_logic.get_king_in_dangered_square()
	
	if !king_in_dangered_square.is_empty() and king_in_dangered_square != new_king_in_dangered_squre:
		# önceki hamlede tehlikede olan bir şah vardı ve yeni hamlede tehlike geçti
		var old_king_in_danger: String = king_in_dangered_square
		king_in_dangered_square = ""
		move_marker_nodes.get_node(old_king_in_danger).queue_free()
	
	king_in_dangered_square = new_king_in_dangered_squre
	if !king_in_dangered_square.is_empty():
		# yeni hamlede tehlikede bir şah var
		add_move_marker(new_king_in_dangered_squre, "red")
	
	var match_finish_state: PackedStringArray = chess_logic.get_match_finished_state().split("_") # örneğin ["finished", "white"] ya da ["not", "finished"]
	
	if match_finish_state[0] == "finished":
		# maç bitti
		match_finished.emit(match_finish_state[1])
		return
	
	if opponent == Enums.Opponent.LOCAL_HUMAN:
		# rakip yerel insan, sıranın kimde oluduğu fark etmeksizin hamle yapmaya izin veriyoruz
		input_conrol_node.show()
	else:
		# rakip AI
		if player_color == chess_logic.get_turn():
			# sıra insanda, hamle yapmaya izin veriyoruz
			input_conrol_node.show()
		else:
			# sıra AI'da, insanın hamle yapmasına izin vermiyoruz ve AI'a hamle yaptırıyoruz
			play_ai_move()


func play_ai_move():
	WorkerThreadPool.add_task(
		func():
			var best_ai_move: String = chess_logic.get_best_ai_move()
			chess_logic.call_deferred("play_ai_move", best_ai_move)
	)


func add_legal_move_markers():
	for legal_move: String in legal_moves:
		var move_array: PackedStringArray = legal_move.split("_") # ["n"-"p"-"e"-"r", hedef kare]
		var piece: String = chess_logic.get_piece_from_square(move_array[1])
		
		if ["p", "e", "r"].has(move_array[0]):
			# hamle özel (promosyon, en passant, rok) sarı işaretliyoruz
			add_move_marker(move_array[1], "yellow")
			
			if move_array[0] == "r" and !["g1", "c1", "g8", "c8"].has(active_square):
				# hamle rok, şah halihazırda rok hedef karesinde değilse, şahın hedef karesini de sarı işaretliyoruz
				add_move_marker(get_king_target_square_in_rook_move(active_square, move_array[1]), "yellow")
		
		elif piece == "empty":
			# hamle normal ve üstüde hedef taş yok, yeşil işaretliyoruz
			add_move_marker(move_array[1], "green")
		
		else:
			# hamle normal ve üstüde hedef taş var, kırmızı işaretliyoruz
			add_move_marker(move_array[1], "red")


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
