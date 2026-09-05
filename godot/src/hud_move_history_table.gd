extends Panel

@onready var master_scene: Control = get_tree().current_scene
@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var sroll_bar: VScrollBar = scroll_container.get_v_scroll_bar()
@onready var element_nodes: VBoxContainer = $ScrollContainer/elements
@onready var instance_element: ColorRect = $ScrollContainer/elements/instance_element

var full_move_number: int = 0


func _on_move_animation_started(move_type: Enums.MoveType, from: String, to: String):
	var color: Enums.ChessColor = master_scene.get_turn()
	if move_type == Enums.MoveType.PROMOTION:
		return
	elif move_type == Enums.MoveType.UNDO:
		match color:
			Enums.ChessColor.WHITE:
				full_move_number -= 1
				element_nodes.get_child(element_nodes.get_child_count() - 1).queue_free()
				update_scroll_container_value()
			Enums.ChessColor.BLACK:
				element_nodes.get_child(element_nodes.get_child_count() - 1).get_node("black_move").text = "..."
	else:
		if move_type != Enums.MoveType.PROMOTION_REQUEST_BY_HUMAN:
			color = Enums.ChessColor.WHITE if color == Enums.ChessColor.BLACK else Enums.ChessColor.BLACK
		if move_type == Enums.MoveType.PUT:
			match master_scene.get_piece_role_from_square(to):
				Enums.Piece.QUEEN: from = "Q"
				Enums.Piece.ROOK: from = "R"
				Enums.Piece.BISHOP: from = "B"
				Enums.Piece.KNIGHT: from = "N"
				Enums.Piece.PAWN: from = "P"
			from += "@"
		else:
			from += "-"
		match color:
			Enums.ChessColor.WHITE:
				full_move_number += 1
				var new_element_node: ColorRect = instance_element.duplicate()
				new_element_node.get_node("move_number").text = str(full_move_number) + "."
				new_element_node.get_node("white_move").text = from + to
				element_nodes.add_child(new_element_node)
				new_element_node.show()
				update_scroll_container_value()
			Enums.ChessColor.BLACK:
				element_nodes.get_child(element_nodes.get_child_count() - 1).get_node("black_move").text = from + "-" + to


func update_scroll_container_value():
	await get_tree().process_frame
	scroll_container.scroll_vertical = int(sroll_bar.max_value)
