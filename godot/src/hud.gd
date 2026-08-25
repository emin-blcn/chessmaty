extends Control

@onready var master_scene: Control = get_tree().current_scene
@onready var undo_message_label_node: Label = $undo_button/undo_message_label
@onready var leave_message_label_node: Label = $leave_button/leave_message_label


func _on_undo_button_pressed() -> void:
	master_scene.undo_last_move()


func _on_undo_button_mouse_entered() -> void:
	undo_message_label_node.show()


func _on_undo_button_mouse_exited() -> void:
	undo_message_label_node.hide()


func _on_leave_button_pressed() -> void:
	if leave_message_label_node.text == "Leave match":
		leave_message_label_node.text = "Click again"
	else:
		master_scene.exit_to_menu()


func _on_leave_button_mouse_entered() -> void:
	leave_message_label_node.show()


func _on_leave_button_mouse_exited() -> void:
	leave_message_label_node.hide()
	if leave_message_label_node.text == "Click again":
		leave_message_label_node.text = "Leave match"
