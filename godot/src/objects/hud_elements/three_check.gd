extends Control

var player_color: Enums.ChessColor

@onready var master_scene: Control = get_tree().current_scene
@onready var black_check_message_label: Label = $black_check_message_label
@onready var black_check_label: Label = $black_check_message_label/check_label
@onready var white_check_message_label: Label = $white_check_message_label
@onready var white_check_label: Label = $white_check_message_label/check_label


func setup(data: Dictionary[String, Variant]) -> void:
	player_color = data.get("player_color")

	# remove this object if game mode is not three check
	if data.get("game_mode") != Enums.GameMode.THREE_CHECK:
		queue_free()
		return

	# reverse vertical gui elements if player side is black (default order is white)
	if player_color == Enums.ChessColor.BLACK:
		black_check_message_label.position.y = 130.0
		white_check_message_label.position.y = 34.0
	show()


func _on_move_animation_finished() -> void:
	# update opposite color's label
	match master_scene.get_active_turn():
		Enums.ChessColor.WHITE:
			update_black_check_label()
		Enums.ChessColor.BLACK:
			update_white_check_label()


func _on_undo_last_move_applied(_double_undo: bool):
	update_white_check_label()
	update_black_check_label()


func update_white_check_label() -> void:
	white_check_label.text = str(master_scene.get_white_checks()) + "/3"


func update_black_check_label() -> void:
	black_check_label.text = str(master_scene.get_black_checks()) + "/3"
