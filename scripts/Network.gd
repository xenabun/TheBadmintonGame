extends Node

const ADDRESS = '127.0.0.1'
const PORT = 5000
var peer

@onready var Level = get_tree().get_first_node_in_group('Level_root')
@onready var UI = get_tree().get_first_node_in_group('UI_root')
@onready var ServerBrowserUI = UI.get_node('ServerBrowser')
@onready var ServerBrowser = get_tree().get_first_node_in_group('ServerBrowser_root')

func _ready():
	multiplayer.server_relay = false
	ServerBrowserUI.host_pressed.connect(_on_host_pressed)
	
	if !multiplayer.is_server(): return
	
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_disconnected)
	multiplayer.connected_to_server.connect(connected_to_server)
	multiplayer.connection_failed.connect(connection_failed)
	ServerBrowser.join_server.connect(join_by_ip)

func peer_connected(id):
	GameManager.print_debug_msg('Player connected ' + str(id))
	if multiplayer.is_server():
		add_player(id)

func peer_disconnected(id):
	GameManager.print_debug_msg('Player disconnected ' + str(id))
	if multiplayer.is_server():
		Level.get_node('World/Ball').set_multiplayer_authority(1)
		del_player_information(id)
		Game.update_score_text_for_all.rpc()
		for player in get_tree().get_nodes_in_group('Player'):
			if str(player.name) == str(id):
				player.queue_free()

##client
func connected_to_server():
	GameManager.print_debug_msg('Connected to server')
	var peer_id = multiplayer.get_unique_id()
	GameManager.Players[peer_id] = {
		'username': UI.get_node('CurrentUsername/VBoxContainer/Username').text,
		'id': peer_id,
	}
	send_player_information.rpc_id(1, 
			UI.get_node('CurrentUsername/VBoxContainer/Username').text, peer_id)
	UI.get_node('Connecting').hide()
	multiplayer.server_disconnected.connect(quit_server)

##client
func connection_failed():
	GameManager.print_debug_msg('Connection failed')
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peer.close()
	GameManager.Players = {}
	Game.game_in_progress = true
	UI.in_menu = true
	UI.in_main_menu = false
	UI.in_server_browser = true

@rpc('any_peer')
func send_player_information(username, id):
	if !GameManager.Players.has(id):
		GameManager.Players[id] = {
			'username': username,
			'id': id,
		}
		Game.update_score_text_for_all.rpc()
	if multiplayer.is_server():
		for player_id in GameManager.Players:
			send_player_information.rpc(GameManager.Players[player_id].username, player_id)
@rpc('any_peer')
func del_player_information(id):
	if !GameManager.Players.has(id): return
	GameManager.Players.erase(id)
	if multiplayer.is_server():
		for player_id in GameManager.Players:
			del_player_information.rpc(player_id)

func _on_host_pressed():
	GameManager.print_debug_msg('host pressed')
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT)
	if error != OK:
		OS.alert('Cannot host: Error code ' + str(error))
		return
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		OS.alert('Failed to start server')
		return
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	Game.current_game_type = Game.game_type.MULTIPLAYER
	multiplayer.set_multiplayer_peer(peer)
	send_player_information(UI.get_node('CurrentUsername/VBoxContainer/Username').text,
			multiplayer.get_unique_id())
	ServerBrowser.broadcast(UI.get_node('CurrentUsername/VBoxContainer/Username').text + "'s server")
	UI.in_menu = false
	UI.in_server_browser = false
	add_player()
	Game.start_game()

func join_by_ip(ip):
	GameManager.print_debug_msg('trying to join by ip: ' + ip)
	peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, PORT)
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		OS.alert('Failed to start client')
		return
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	Game.current_game_type = Game.game_type.MULTIPLAYER
	multiplayer.set_multiplayer_peer(peer)
	UI.in_menu = false
	UI.in_server_browser = false
	UI.get_node('Connecting').show()

func quit_server():
	if multiplayer.server_disconnected.is_connected(quit_server):
		multiplayer.server_disconnected.disconnect(quit_server)
	Game.current_game_type = Game.game_type.NONE
	if peer: peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	GameManager.Players = {}
	Game.game_in_progress = true
	Game.reset_ball()
	UI.in_menu = true
	UI.in_server_browser = false
	UI.in_main_menu = true
	if multiplayer.is_server():
		ServerBrowser.stop_broadcast()
		for player in get_tree().get_nodes_in_group('Player'):
			player.queue_free()
		for bot in get_tree().get_nodes_in_group('Bot'):
			bot.queue_free()

func start_singleplayer():
	Game.current_game_type = Game.game_type.SINGLEPLAYER
	UI.in_menu = false
	UI.in_main_menu = false
	var bot_username = 'Компьютер'
	GameManager.Players[1] = {
		'username': UI.get_node('CurrentUsername/VBoxContainer/Username').text,
		'id': 1,
	}
	GameManager.Players[2] = {
		'username': bot_username,
		'id': 2,
	}
	var plr_char = add_player()
	add_bot(plr_char, bot_username)
	Game.start_game()

func add_player(id: int = 1):
	GameManager.print_debug_msg('adding player ' + str(id) + ' by ' + str(multiplayer.get_unique_id()))
	if Level.get_node('Players').has_node(str(id)): return
	
	var character = preload("res://prefabs/Player.tscn").instantiate()
	character.player_id = id
	character.name = str(id)
	var num = 1 if id == 1 else 2
	var spawn_point = Level.get_node('World/Player' + str(num) + 'Spawn')
	character.position = spawn_point.position
	character.rotation = spawn_point.rotation
	Level.get_node('Players').add_child(character, true)
	Game.update_score_text_for_all.rpc()
	return character

func add_bot(player_char, bot_username):
	var character = preload("res://prefabs/Bot.tscn").instantiate()
	character.player = player_char
	character.get_node('Username').text = bot_username
	var spawn_point = Level.get_node('World/Player2Spawn')
	character.position = spawn_point.position
	character.rotation = spawn_point.rotation
	Level.get_node('Players').add_child(character, true)
	Game.update_score_text()

var con = [
	'CONNECTION_DISCONNECTED',
	'CONNECTION_CONNECTING',
	'CONNECTION_CONNECTED',
]
func _process(_delta):
	if not Game.debug:
		set_process(false)
		return
	
	if peer:
		var status = peer.get_connection_status()
		GameManager.set_connection_status_text('Connection status: ' + con[status])
	else:
		GameManager.set_connection_status_text('Connection status: -')
