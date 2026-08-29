extends Control

signal config_finished(config_data: Dictionary[String, Variant])

const time_per_side_minute_values: PackedFloat64Array = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0,
	13.0, 14.0, 15.0, 16.0, 17.0,18.0, 19.0, 20.0, 25.0, 30.0, 35.0, 40.0, 45.0, 60.0, 75.0, 90.0, 105.0, 120.0, 135.0, 150.0, 165.0, 180.0, -1.0]
const time_increment_second_values: PackedInt64Array = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
	10, 11, 12, 13, 14, 15, 16,17, 18, 19, 20, 25, 30, 35, 40, 45, 60, 90, 120, 150, 180]

@onready var master_scene: Control = get_tree().current_scene
@onready var create_host_config_node: Control = $TabContainer/create/create_host_config
@onready var host_name_line_edit: LineEdit = $TabContainer/create/create_host_config/host_name_line_edit
@onready var game_mode_button: Button = $TabContainer/create/create_host_config/game_mode_button
@onready var player_color_button: Button = $TabContainer/create/create_host_config/player_color_button
@onready var time_per_side_label: Label = $TabContainer/create/create_host_config/time_per_side_bar/time_per_side_label
@onready var time_increment_bar: HScrollBar = $TabContainer/create/create_host_config/time_increment_bar
@onready var time_increment_label: Label = $TabContainer/create/create_host_config/time_increment_bar/time_increment_label

@onready var wait_for_peer_node: Control = $TabContainer/create/wait_for_peer
@onready var cancel_waiting_for_peer_button: Button = $TabContainer/create/wait_for_peer/cancel_waiting_for_peer_button

@onready var refresh_host_list_button: Button = $TabContainer/join/refresh_host_list_button
@onready var element_nodes: VBoxContainer = $TabContainer/join/ColorRect/ScrollContainer/elements
@onready var element_instance_node: ColorRect = $TabContainer/join/ColorRect/ScrollContainer/elements/element_instance

var lan_host: LanHost = LanHost.new()
var lan_peer: LanPeer = LanPeer.new()
var is_discovering_hosts: bool = false
var is_waiting_for_peer: bool = false
var config_data: Dictionary[String, Variant] = {
	"host_name": "New Match",
	"player_color": Enums.ChessColor.WHITE,
	"game_mode": Enums.GameMode.STANDARD,
	"fen_string": "",
	"connection_type": Enums.ConnectionType.LAN,
	"time_per_side": -60_000,
	"time_increment": 0}


func _on_game_config_tab_changed(tab: int) -> void:
	if tab == 1:
		discover_hosts()


func _on_refresh_host_list_button_pressed() -> void:
	discover_hosts()


func discover_hosts():
	if is_discovering_hosts:
		return
	is_discovering_hosts = true
	
	refresh_host_list_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	refresh_host_list_button.modulate.a = 0.5
	cancel_waiting_for_peer_button.hide()
	
	for element: ColorRect in element_nodes.get_children():
		if element != element_instance_node:
			element.queue_free()
	
	WorkerThreadPool.add_task(_discover_hosts)


func _discover_hosts():
	var discovered_hosts: Dictionary[String, String] = lan_peer.discover_all_hosts()
	call_deferred("_on_discovered_all_hosts", discovered_hosts)


func _on_discovered_all_hosts(discovered_hosts: Dictionary[String, String]):
	for key_ip in discovered_hosts.keys():
		var value: String = discovered_hosts[key_ip]
		var data_list: PackedStringArray = value.split("|")
		# (DISCOVERY_PONG_MSG, host_name, player_color, game_mode, fen_string, time_per_side, time_increment)
		var host_config_data: Dictionary[String, Variant] = {
			"host_name": data_list[1],
			"player_color": int(data_list[2]) as Enums.ChessColor,
			"game_mode": int(data_list[3]) as Enums.GameMode,
			"fen_string": data_list[4],
			"time_per_side": int(data_list[5]),
			"time_increment": int(data_list[6])}
		
		var new_element_node: ColorRect = element_instance_node.duplicate()
		var join_button: Button = new_element_node.get_node("join_button")
		
		join_button.pressed.connect(_on_join_button_pressed.bind(key_ip, host_config_data))
		
		new_element_node.get_node("host_name_label").text = host_config_data["host_name"]
		
		match host_config_data["game_mode"]:
			Enums.GameMode.STANDARD:
				new_element_node.get_node("HBoxContainer/game_mode_label").text = "game mode (Standard)"
			Enums.GameMode.CHESS960:
				new_element_node.get_node("HBoxContainer/game_mode_label").text = "game mode (Chess960)"
		
		match host_config_data["player_color"]:
			Enums.ChessColor.WHITE:
				new_element_node.get_node("HBoxContainer/player_color_label").text = "Player side (white)"
			Enums.ChessColor.BLACK:
				new_element_node.get_node("HBoxContainer/player_color_label").text = "Player side (black)"
		
		if host_config_data["time_per_side"] == -60_000:
			new_element_node.get_node("HBoxContainer2/minute_per_side_label").text = "no time limit"
			new_element_node.get_node("HBoxContainer2/increment_second_label").hide()
		else:
			@warning_ignore_start("integer_division")
			var minute_per_side: float = float(host_config_data["time_per_side"]) / 60.0 / 1000.0
			if str(minute_per_side).split(".")[1] == "0":
				new_element_node.get_node("HBoxContainer2/minute_per_side_label").text = "minute per side (" + str(int(host_config_data["time_per_side"]) / 60 / 1000) + ")"
			else:
				new_element_node.get_node("HBoxContainer2/minute_per_side_label").text = "minute per side (" + str(host_config_data["time_per_side"] / 60.0 / 1000.0) + ")"
			
			if host_config_data["time_increment"] == 0:
				new_element_node.get_node("HBoxContainer2/increment_second_label").text = "no time increment"
			else:
				new_element_node.get_node("HBoxContainer2/increment_second_label").text = "increment in seconds (" + str(host_config_data["time_increment"] / 1000) + ")"
			@warning_ignore_restore("integer_division")
		
		element_nodes.add_child(new_element_node)
		new_element_node.show()
	
	refresh_host_list_button.mouse_filter = Control.MOUSE_FILTER_STOP
	refresh_host_list_button.modulate.a = 1.0
	cancel_waiting_for_peer_button.show()
	is_discovering_hosts = false


func _on_join_button_pressed(host_ip: String, host_config_data: Dictionary[String, Variant]):
	var is_accepted_join_request: bool = lan_peer.join_host(host_ip)
	if !is_accepted_join_request:
		return
	
	config_data["host_name"] = host_config_data["host_name"]
	match host_config_data["player_color"]:
		Enums.ChessColor.WHITE:
			config_data["player_color"] = Enums.ChessColor.BLACK
		Enums.ChessColor.BLACK:
			config_data["player_color"] = Enums.ChessColor.WHITE
	config_data["game_mode"] = host_config_data["game_mode"]
	config_data["fen_string"] = host_config_data["fen_string"]
	config_data["time_per_side"] = host_config_data["time_per_side"]
	config_data["time_increment"] = host_config_data["time_increment"]
	
	lan_host = null
	master_scene.init_stream(lan_peer)
	config_finished.emit(config_data)


func _on_player_color_button_pressed() -> void:
	match config_data["player_color"]:
		Enums.ChessColor.WHITE:
			config_data["player_color"] = Enums.ChessColor.BLACK
			player_color_button.text = "Player side: Black"
		Enums.ChessColor.BLACK:
			config_data["player_color"] = Enums.ChessColor.WHITE
			player_color_button.text = "Player side: White"


func _on_game_mode_button_pressed() -> void:
	match config_data["game_mode"]:
		Enums.GameMode.STANDARD:
			config_data["game_mode"] = Enums.GameMode.CHESS960
			game_mode_button.text = "Game mode: Chess960"
		Enums.GameMode.CHESS960:
			config_data["game_mode"] = Enums.GameMode.KING_OF_THE_HILL
			game_mode_button.text = "Game mode: King of the hill"
		Enums.GameMode.KING_OF_THE_HILL:
			config_data["game_mode"] = Enums.GameMode.THREE_CHECK
			game_mode_button.text = "Game mode: Three check"
		Enums.GameMode.THREE_CHECK:
			config_data["game_mode"] = Enums.GameMode.STANDARD
			game_mode_button.text = "Game mode: Standard"



func _on_time_per_side_bar_value_changed(value: float) -> void:
	var index: int = int(value)
	var new_minute: float = time_per_side_minute_values[index]
	var new_time: int = int(new_minute * 60 * 1000)
	
	config_data["time_per_side"] = new_time
	
	if new_time == -60_000:
		time_per_side_label.text = "Minutes per side: Unlimited"
		time_increment_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		time_increment_bar.modulate.a = 0.5
		time_increment_label.modulate.a = 0.5
	else:
		if str(new_minute).split(".")[1] == "0":
			time_per_side_label.text = "Minutes per side: " + str(int(new_minute))
		else:
			time_per_side_label.text = "Minutes per side: " + str(new_minute)
		time_increment_bar.mouse_filter = Control.MOUSE_FILTER_STOP
		time_increment_bar.modulate.a = 1.0
		time_increment_label.modulate.a = 1.0


func _on_time_increment_bar_value_changed(value: float) -> void:
	config_data["time_increment"] = time_increment_second_values[int(value)] * 1000
	time_increment_label.text = "Increment in seconds " + str(time_increment_second_values[int(value)])


func _on_crate_host_button_pressed() -> void:
	wait_for_peer()


func wait_for_peer():
	if is_waiting_for_peer:
		return
	is_waiting_for_peer = true
	
	create_host_config_node.hide()
	wait_for_peer_node.show()
	
	WorkerThreadPool.add_task(_wait_for_peer)


func _wait_for_peer():
	if config_data["game_mode"] == Enums.GameMode.CHESS960:
		config_data["fen_string"] = ChessLogic.random_fen()
	
	var peer_joined: bool = lan_host.wait_for_peer(config_data)
	if peer_joined:
		call_deferred("_on_join_request_received_from_peer")


func _on_join_request_received_from_peer() -> void:
	lan_peer = null
	master_scene.init_stream(lan_host)
	config_finished.emit(config_data)


func _on_cancel_waiting_for_peer_button_pressed() -> void:
	cancel_waiting_for_peer()


func cancel_waiting_for_peer() -> void:
	lan_host.cancel_waiting_for_peer()
	wait_for_peer_node.hide()
	create_host_config_node.show()
	is_waiting_for_peer = false


func _on_back_button_pressed() -> void:
	if is_waiting_for_peer:
		cancel_waiting_for_peer()
	get_tree().change_scene_to_file("uid://dwnbfraut6h7t")
