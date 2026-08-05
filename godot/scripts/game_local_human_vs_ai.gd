extends Control

@onready var chess_board_node: Control = $chess_board
@onready var promotion_selection_node: Control = $promotion_selection

var opponent: Enums.Opponent = Enums.Opponent.LOCAL_AI
var game_mode: Enums.GameMode = Enums.GameMode.CHESS960
var player_color: Enums.ChessColor = Enums.ChessColor.WHITE


func _ready() -> void:
	chess_board_node.opponent = opponent
	chess_board_node.game_mode = game_mode
	chess_board_node.player_color = player_color
	chess_board_node.ai_binary_path = get_ai_binary_path()
	chess_board_node.initialize_board()
	chess_board_node.move_animation_started.connect(_on_move_animation_started)
	chess_board_node.move_animation_finished.connect(_on_move_animation_finished)
	chess_board_node.promotion_selection_required.connect(_on_promotion_selection_required)
	chess_board_node.match_finished.connect(_on_match_finished)
	
	match player_color:
		Enums.ChessColor.WHITE:
			promotion_selection_node.get_node("black").queue_free()
			
			for selection_button: Button in promotion_selection_node.get_node("white").get_children():
				selection_button.button_up.connect(_on_promotion_selected.bind(selection_button.name))
		
		Enums.ChessColor.BLACK:
			promotion_selection_node.get_node("white").queue_free()
			
			for selection_button: Button in promotion_selection_node.get_node("black").get_children():
				selection_button.button_up.connect(_on_promotion_selected.bind(selection_button.name))



func _on_move_animation_started(_move_type: String):
	pass


func _on_move_animation_finished(_move_type: String):
	pass


func _on_promotion_selection_required():
	promotion_selection_node.show()


func _on_promotion_selected(selected_piece: String):
	chess_board_node.apply_promotion_move(selected_piece)
	promotion_selection_node.hide()


func _on_match_finished(winner: String):
	match winner:
		"draw":
			print("maç berabere bitti")
		"white":
			print("beyaz maçı kazandı")
		"black":
			print("siyah maçı kazandı")


func get_ai_binary_path() -> String:
	var ai_bin_file_name: String
	
	match [OS.get_name(), Engine.get_architecture_name()]:
		["Linux", "x86_64"]:
			ai_bin_file_name = "stockfish_linux_x86_64_avx2"
		["Windows", "x86_64"]:
			ai_bin_file_name = "stockfish_windows_x86_64_avx2.exe"
	
	if OS.has_feature("editor"):
		# oyun editörde çalıştırıldı, satranç motorunun yolunu proje dizinine göre alıyoruz
		return ProjectSettings.globalize_path("res://").get_base_dir().get_base_dir().path_join("bin").path_join(ai_bin_file_name)
	else:
		# oyun export edildi ve çalıştırıldı, oyunun çalıştırılabilir dosyasının yanındaki satranç motorunun yolunu alıyoruz
		return OS.get_executable_path().get_base_dir().path_join(ai_bin_file_name)
