extends VBoxContainer

var full_move_number: int = 0

@onready var master_scene: Control = get_tree().current_scene
@onready var scroll_container: ScrollContainer = $Panel/ScrollContainer
@onready var sroll_bar: VScrollBar = scroll_container.get_v_scroll_bar()
@onready var elements_node: VBoxContainer = $Panel/ScrollContainer/elements
@onready var instance_element: NinePatchRect = $Panel/ScrollContainer/elements/instance_element


func _on_move_applied(_move_type: Enums.MoveType, from: String, to: String) -> void:
	var color: Enums.ChessColor = Enums.ChessColor.WHITE if master_scene.get_turn() == Enums.ChessColor.BLACK else Enums.ChessColor.BLACK
	match color:
		Enums.ChessColor.WHITE:
			full_move_number += 1
			var new_element_node: NinePatchRect = instance_element.duplicate()
			new_element_node.get_node("move_number_label").text = str(full_move_number) + "."
			new_element_node.get_node("white_texture_rect/white_move_label").text = from + "-" + to
			elements_node.add_child(new_element_node)
			new_element_node.show()
			update_scroll_container_value()
		Enums.ChessColor.BLACK:
			elements_node.get_child(elements_node.get_child_count() - 1).get_node("black_texture_rect/black_move_label").text = from + "-" + to


func _on_promotion_piece_updated(from: String, to: String, role: Enums.PieceRole) -> void:
	var color: Enums.ChessColor = Enums.ChessColor.WHITE if master_scene.get_turn() == Enums.ChessColor.BLACK else Enums.ChessColor.BLACK
	
	match role:
		Enums.PieceRole.QUEEN: to += "q"
		Enums.PieceRole.ROOK: to += " r"
		Enums.PieceRole.BISHOP: to += "b"
		Enums.PieceRole.KNIGHT: to += "n"
	
	match color:
		Enums.ChessColor.WHITE:
			full_move_number += 1
			var new_element_node: NinePatchRect = instance_element.duplicate()
			new_element_node.get_node("move_number_label").text = str(full_move_number) + "."
			new_element_node.get_node("white_texture_rect/white_move_label").text = from + "-" + to
			elements_node.add_child(new_element_node)
			new_element_node.show()
			update_scroll_container_value()
		Enums.ChessColor.BLACK:
			elements_node.get_child(elements_node.get_child_count() - 1).get_node("black_texture_rect/black_move_label").text = from + "-" + to


func _on_put_move_applied(_role: Enums.PieceRole, to: String) -> void:
	var color: Enums.ChessColor = Enums.ChessColor.WHITE if master_scene.get_turn() == Enums.ChessColor.BLACK else Enums.ChessColor.BLACK
	
	match master_scene.get_piece_role_from_square(to):
		Enums.PieceRole.QUEEN: to = to.insert(0, "Q@")
		Enums.PieceRole.ROOK: to = to.insert(0, "R@")
		Enums.PieceRole.BISHOP: to = to.insert(0, "B@")
		Enums.PieceRole.KNIGHT: to = to.insert(0, "N@")
		Enums.PieceRole.PAWN: to = to.insert(0, "P@")
	
	match color:
		Enums.ChessColor.WHITE:
			full_move_number += 1
			var new_element_node: NinePatchRect = instance_element.duplicate()
			new_element_node.get_node("move_number_label").text = str(full_move_number) + "."
			new_element_node.get_node("white_texture_rect/white_move_label").text = to
			elements_node.add_child(new_element_node)
			new_element_node.show()
			update_scroll_container_value()
		Enums.ChessColor.BLACK:
			elements_node.get_child(elements_node.get_child_count() - 1).get_node("black_texture_rect/black_move_label").text = to


func _on_undoed_last_move(double_undo: bool):
	for _i in range(2):
		var last_element_instance: NinePatchRect = elements_node.get_child(elements_node.get_child_count() - 1)
		var last_element_instance_black_label: Label = last_element_instance.get_node("black_texture_rect/black_move_label")
		
		if last_element_instance_black_label.text == "...":
			full_move_number -= 1
			last_element_instance.queue_free()
		else:
			last_element_instance_black_label.text = "..."
		
		if !double_undo:
			break


func update_scroll_container_value() -> void:
	await get_tree().process_frame
	scroll_container.scroll_vertical = int(sroll_bar.max_value)
