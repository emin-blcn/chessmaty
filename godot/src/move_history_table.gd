extends Panel

@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var element_nodes: VBoxContainer = $ScrollContainer/elements
@onready var instance_element_node: ColorRect = $ScrollContainer/elements/instance_element

var full_move_number: int = 0


func add_element(player_color: Enums.ChessColor, from: String, to: String):
	match player_color:
		Enums.ChessColor.WHITE:
			full_move_number += 1
			var new_element_node: ColorRect = instance_element_node.duplicate()
			new_element_node.get_node("move_number").text = str(full_move_number) + "."
			new_element_node.get_node("white_move").text = from + "-" + to
			element_nodes.add_child(new_element_node)
			new_element_node.show()
			update_sroll()
		Enums.ChessColor.BLACK:
			element_nodes.get_child(element_nodes.get_child_count() - 1).get_node("black_move").text = from + "-" + to


func remove_element(player_color: Enums.ChessColor):
	match player_color:
		Enums.ChessColor.WHITE:
			full_move_number -= 1
			element_nodes.get_child(element_nodes.get_child_count() - 1).queue_free()
			update_sroll()
		Enums.ChessColor.BLACK:
			element_nodes.get_child(element_nodes.get_child_count() - 1).get_node("black_move").text = "..."


func update_sroll():
	await get_tree().process_frame
	var sroll_bar: VScrollBar = scroll_container.get_v_scroll_bar()
	scroll_container.scroll_vertical = int (sroll_bar.max_value)
