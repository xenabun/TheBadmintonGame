extends Control

@export var menu_camera_pivot : Node
@export var player_camera : Node
@export var in_menu : bool = true :
	set(value):
		get_node('ServerBrowser').visible = value
		menu_camera_pivot.get_node('MenuCamera').set_current(value)
		in_menu = value
		if value == true:
			get_node('GameUI').hide()
			get_node('Menu').hide()
			get_node('GameResult').hide()
			get_node('Connecting').hide()
			player_camera.set_current(false)
@onready var ServerBrowser = get_tree().get_first_node_in_group('ServerBrowser_root')

func _on_back_pressed():
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	GameManager.Players = {}
	Game.game_in_progress = true
	in_menu = true
	if multiplayer.is_server():
		ServerBrowser.stop_broadcast()
		for player in get_tree().get_nodes_in_group('Player'):
			player.queue_free()

func _on_close_pressed():
	get_node('Menu').hide()

func _physics_process(_delta):
	if in_menu and Game.window_focus:
		menu_camera_pivot.rotation.y += 0.0005


