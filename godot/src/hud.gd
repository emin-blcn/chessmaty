extends Control

@onready var undo_message_label_node: Label = $undo_button/undo_message_label
@onready var leave_message_label_node: Label = $leave_button/leave_message_label


func _on_undo_button_pressed() -> void:
	#chess_board_node.undo_last_move()
	print("HUD undo button pressed")


func _on_undo_button_mouse_entered() -> void:
	undo_message_label_node.show()


func _on_undo_button_mouse_exited() -> void:
	undo_message_label_node.hide()


func _on_leave_button_pressed() -> void:
	if leave_message_label_node.text == "Leave match":
		leave_message_label_node.text = "Click again"
	else:
		get_tree().change_scene_to_file("uid://dwnbfraut6h7t")


func _on_leave_button_mouse_entered() -> void:
	leave_message_label_node.show()


func _on_leave_button_mouse_exited() -> void:
	leave_message_label_node.hide()
	if leave_message_label_node.text == "Click again":
		leave_message_label_node.text = "Leave match"
