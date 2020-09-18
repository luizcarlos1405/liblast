extends Spatial

export var SERVER_PORT = 9999 setget , get_port
export(String, "172.28.162.191", "172.28.166.24", "127.0.0.1")  var SERVER_IP = "172.28.162.191" setget , get_ip
export var MAX_PLAYERS = 10
export (String, "MENU", "PLAYING") var GAME_MODE = "MENU"

var mouse_sensitivity_multiplier = 1.0

var player_scene = preload("res://Player.tscn")

var settingmap = {
	"is_fullscreen": "set_fullscreen",
	"mouse_sensitivity": "set_mouse_sensitivity"
}

# Called when the node enters the scene tree for the first time.
func _ready():
	$MenuContainer/MainMenu/Destination/IPAdress.set_text(SERVER_IP)
	$MenuContainer/MainMenu/Destination/Port.set_text(str(SERVER_PORT))
	
	load_settings()

func load_settings():
	var load_settings = File.new()
	load_settings.open("user://settings.save", File.READ)
	
	if load_settings.is_open():
		var settings = parse_json(load_settings.get_as_text())
		
		for setting in settings:
			load_setting(setting, settings[setting])

func load_setting(setting, value):
	call(settingmap[setting], value, false)

func save_setting(setting, value):
	var save_settings = File.new()
	save_settings.open("user://settings.save", File.READ_WRITE)
	
	if save_settings.is_open():
		var settings = parse_json(save_settings.get_as_text())
		settings[setting] = value
		save_settings.store_string(to_json(settings))
	else:
		save_settings.close()
		save_settings.open("user://settings.save", File.WRITE)
		var settings = {setting: value}
		save_settings.store_string(to_json(settings))

func _input(event):
	if event.is_action_pressed("ToggleMenu"):
		if GAME_MODE == "PLAYING" and not $MenuContainer.is_visible():
			open_menus()
		elif $MenuContainer/MainMenu.is_visible():
			close_menus()
		else:
			# Find the back button
			var children = $MenuContainer.get_children()
			for child in children:
				if child.is_visible():
					var buttons = child.get_children()
					for button in buttons:
						if button.name == "Back":
							print(child.name)
							button.emit_signal("pressed")

func open_menus():
	GAME_MODE = "MENU"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	$MenuContainer.show()

func close_menus():
	GAME_MODE = "PLAYING"
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	$MenuContainer.hide()

func return_to_menu(type):
	for menu in $MenuContainer.get_children():
		if menu.name == type:
			menu.show()
		else:
			menu.hide()

func open_menu(type):
	for menu in $MenuContainer.get_children():
		if menu.name == type:
			menu.show()
		else:
			menu.hide()

func join_home():
	SERVER_IP = "127.0.0.1"
	initialize_client()

func join_unfa():
	SERVER_IP = "172.25.162.191"
	initialize_client()

func join_jan():
	SERVER_IP = "172.25.166.24"
	initialize_client()

func set_ip(ip):
	SERVER_IP = ip

func set_mouse_sensitivity(sensitivity_multiplier, save=true):
	if mouse_sensitivity_multiplier != sensitivity_multiplier:
		mouse_sensitivity_multiplier = sensitivity_multiplier
	else:
		return
	
	if save:
		save_setting("mouse_sensitivity", sensitivity_multiplier)
	else:
		$MenuContainer/ControlsMenu/HBoxContainer/SensitivitySlider.value = sensitivity_multiplier

func set_fullscreen(is_fullscreen, save=true):
	if OS.window_fullscreen != is_fullscreen:
		OS.window_fullscreen = is_fullscreen
	else:
		return
	
	if save:
		save_setting("is_fullscreen", is_fullscreen)
	else:
		$MenuContainer/GraphicsMenu/Fullscreen.pressed = is_fullscreen

func debug_connection_status():
	if (get_tree().network_peer.get_connection_status() == NetworkedMultiplayerPeer.CONNECTION_CONNECTING):
		print("We are trying to connect")

func get_ip():
	return SERVER_IP

func get_port():
	return SERVER_PORT

func initialize_server():
	var peer = NetworkedMultiplayerENet.new()
	peer.create_server(SERVER_PORT, MAX_PLAYERS)
	get_tree().connect("network_peer_connected", self, "on_peer_connected")
	get_tree().connect("network_peer_disconnected", self, "on_peer_disconnected")
	get_tree().network_peer = peer
	close_menus()
	add_player(1, false)

func initialize_client():
	var peer = NetworkedMultiplayerENet.new()
	peer.create_client(SERVER_IP, SERVER_PORT)
	get_tree().connect("connected_to_server", self, "on_connection_established")
	get_tree().connect("connection_failed", self, "on_connection_failed")
	get_tree().network_peer = peer
	close_menus()

func quit():
	get_tree().quit()

func get_player_names():
	var players =  $Players.get_children()
	
	var player_names = []
	for player in players:
		player_names.append(player.name)
	
	return player_names

sync func check_players(player_names):
	for player_name in player_names:
		if not $Players.has_node(player_name):
			var player = player_scene.instance()
			
			player.name = player_name
			$Players.add_child(player)
			player.translation += Vector3(0.0, 3.0, 0.0)
			
			if player_name == str(get_tree().get_network_unique_id()):
				player.camera.current = true
				player.set_network_master(get_tree().get_network_unique_id())
				print(get_tree().get_network_unique_id())

func add_player(id, check=true):
	var player = player_scene.instance()
	
	player.name = str(id)
	$Players.add_child(player)
	player.set_network_master(id)
	player.translation += Vector3(0.0, 0.0, 0.0)
	
	var player_names = get_player_names()
	
	if check:
		rpc("check_players", player_names)

sync func remove_player(id):
	for player in $Players.get_children():
		if player.name == str(id):
			$Players.remove_child(player)

func get_spawn_point():
	return $Level/SpawnPoint

func on_peer_connected(id):
	print("Peer connected with id ", id)
	
	add_player(id)

func on_peer_disconnected(id):
	print("Peer disconnected with id ", id)
	
	rpc("remove_player", id)

func on_connection_established():
	print("Connection has been established")

func on_connection_failed():
	print("Connection has failed")
