extends Control

@onready var master_scene: Control = get_tree().current_scene
@onready var undo_button: Button = $undo_button
@onready var undo_message_label_node: Label = $undo_button/undo_message_label
@onready var undo_state_animator_node: AnimationPlayer = $undo_button/undo_state_animator
@onready var leave_message_label_node: Label = $leave_button/leave_message_label

var connection_type: Enums.ConnectionType

func config(new_config_data: Dictionary[String, Variant]):
	connection_type = new_config_data["connection_type"]
	
	if new_config_data["connection_type"] == Enums.ConnectionType.LOCAL:
		$received_undo_request.queue_free()
		$undo_button/undo_state_animator.queue_free()
	else:
		undo_message_label_node.text = "Send undo request"


func _on_move_animation_started(move_type: Enums.MoveType, _from: String, _to: String):
	if move_type != Enums.MoveType.PROMOTION:
		hide_undo_button()


func hide_undo_button():
	undo_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	undo_button.self_modulate.a = 0.5


func show_undo_button():
	undo_button.mouse_filter = Control.MOUSE_FILTER_STOP
	undo_button.self_modulate.a = 1.0


func _on_undo_button_pressed() -> void:
	if (connection_type != Enums.ConnectionType.LOCAL
	and master_scene.is_undoable()
	and undo_state_animator_node.current_animation != "undo_response_waiting"):
		undo_state_animator_node.play("undo_response_waiting")
	master_scene.undo_last_move()


func _on_responded_undo_request(accept: bool):
	if accept:
		undo_state_animator_node.play("undo_request_accepted")
	else:
		undo_state_animator_node.play("undo_request_rejected")


func _on_undo_button_mouse_entered() -> void:
	undo_message_label_node.show()


func _on_undo_button_mouse_exited() -> void:
	if connection_type == Enums.ConnectionType.LOCAL:
		undo_message_label_node.hide()
	elif !undo_state_animator_node.is_playing():
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
	leave_message_label_node.text = "Leave match"
