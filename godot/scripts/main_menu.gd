extends Control

const GAME_LOCAL_HUMAN_VS_HUMAN_SCENE = preload("uid://ccx66rc44ejbv")
const GAME_LOCAL_HUMAN_VS_AI_SCENE = preload("uid://dj81jubt01fjr")


func _on_button_button_up() -> void:
	get_tree().change_scene_to_packed(GAME_LOCAL_HUMAN_VS_HUMAN_SCENE)


func _on_button_2_button_up() -> void:
	get_tree().change_scene_to_packed(GAME_LOCAL_HUMAN_VS_AI_SCENE)


func _on_button_3_button_up() -> void:
	get_tree().quit()
