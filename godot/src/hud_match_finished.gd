extends TextureRect

@onready var master_scene: Control = get_tree().current_scene


func _on_rematch_button_pressed() -> void:
	get_tree().reload_current_scene()


func _on_undo_button_pressed() -> void:
	master_scene.undo_last_move()


func _on_leave_button_pressed() -> void:
	get_tree().change_scene_to_file("uid://dwnbfraut6h7t")
