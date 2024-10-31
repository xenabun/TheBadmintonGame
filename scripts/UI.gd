extends Control

@export var menu_camera_pivot : Node
@export var player_camera : Node
@export var in_menu : bool = true :
	set(value):
		get_node('ServerBrowser').visible = value
		menu_camera_pivot.get_node('MenuCamera').set_current(value)
		in_menu = value
		if value == true:
			get_node('GameUI').visible = false
			get_node('Menu').visible = false
			player_camera.set_current(false)
@onready var ServerBrowser = get_tree().get_first_node_in_group('ServerBrowser_root')

func _on_back_pressed():
	if multiplayer.is_server():
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		ServerBrowser.stop_broadcast()
		for player in get_tree().get_nodes_in_group('Player'):
			player.queue_free()
		GameManager.Players = {}
	else:
		var peer = multiplayer.multiplayer_peer
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		peer.close()
		GameManager.Players = {}
	in_menu = true

func _on_close_pressed():
	get_node('Menu').visible = false

func _physics_process(_delta):
	if in_menu and Game.window_focus:
		menu_camera_pivot.rotation.y += 0.0005


