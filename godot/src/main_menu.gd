extends Control

const GAME_LOCAL_SCENE = preload("uid://ccx66rc44ejbv")


func _on_local_game_button_pressed() -> void:
	get_tree().change_scene_to_packed(GAME_LOCAL_SCENE)


func _on_button_3_button_up() -> void:
	get_tree().quit()
