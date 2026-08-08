extends ColorRect

@onready var element_nodes: VBoxContainer = $NinePatchRect/ScrollContainer/elements
@onready var instance_element_node: HBoxContainer = $NinePatchRect/ScrollContainer/elements/instance_element

var full_move_number: int = 0


func add_element(player_color: Enums.ChessColor, from: String, to: String):
	match player_color:
		Enums.ChessColor.WHITE:
			full_move_number += 1
			var new_element_node: HBoxContainer = instance_element_node.duplicate()
			new_element_node.get_child(0).text = str(full_move_number) + "."
			new_element_node.get_child(1).get_node("white_move").text = from + "-" + to
			element_nodes.add_child(new_element_node)
			new_element_node.show()
		Enums.ChessColor.BLACK:
			element_nodes.get_child(element_nodes.get_child_count() - 1).get_child(1).get_node("black_move").text = from + "-" + to


func remove_element(player_color: Enums.ChessColor):
	match player_color:
		Enums.ChessColor.WHITE:
			full_move_number -= 1
			element_nodes.get_child(element_nodes.get_child_count() - 1).queue_free()
		Enums.ChessColor.BLACK:
			element_nodes.get_child(element_nodes.get_child_count() - 1).get_child(1).get_node("black_move").text = "..."
