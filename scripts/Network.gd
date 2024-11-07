extends Node

const ADDRESS = '127.0.0.1'
const PORT = 5000 #49664
var peer

@onready var Level = get_tree().get_first_node_in_group('Level_root')
@onready var UI = get_tree().get_first_node_in_group('UI_root')
@onready var ServerBrowserUI = UI.get_node('ServerBrowser')
@onready var ServerBrowser = get_tree().get_first_node_in_group('ServerBrowser_root')

func _ready():
	multiplayer.server_relay = false
	ServerBrowserUI.host_pressed.connect(_on_host_pressed)
	
	if !multiplayer.is_server():
		return
	#multiplayer.peer_connected.connect(add_player)
	#multiplayer.peer_disconnected.connect(del_player)
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_disconnected)
	multiplayer.connected_to_server.connect(connected_to_server)
	multiplayer.connection_failed.connect(connection_failed)
	
	ServerBrowser.join_server.connect(join_by_ip)
	#for id in multiplayer.get_peers():
		#add_player(id)

func peer_connected(id):
	GameManager.print_debug_msg('Player connected ' + str(id))
	#add_player(id)
	if multiplayer.is_server():
		add_player(id)

func peer_disconnected(id):
	GameManager.print_debug_msg('Player disconnected ' + str(id))
	#GameManager.Players.erase(id)
	if multiplayer.is_server():
		Level.get_node('World/Ball').set_multiplayer_authority(1)
		del_player_information(id)
		Game.update_score_text_for_all.rpc()
		for player in get_tree().get_nodes_in_group('Player'):
			if str(player.name) == str(id):
				player.queue_free()
	
	#print(multiplayer.get_unique_id())
	#if multiplayer.is_server():
		#for player in get_tree().get_nodes_in_group('Player'):
			#disconnect_peer.rpc(str(player.name).to_int())
			#player.queue_free()
		#clear_player_information()
	#else:
		#del_player_information(id)
		#for player in get_tree().get_nodes_in_group('Player'):
			#if player.name == str(id):
				#player.queue_free()
#@rpc("any_peer")
#func disconnect_peer():
	#multiplayer.multiplayer_peer.disconnect_peer(1)

##client
func connected_to_server():
	GameManager.print_debug_msg('Connected to server')
	var peer_id = multiplayer.get_unique_id()
	GameManager.Players[peer_id] = {
		'username': ServerBrowserUI.get_node('UsernameBox').text,
		'id': peer_id,
	}
	send_player_information.rpc_id(1, ServerBrowserUI.get_node('UsernameBox').text, peer_id)
	UI.get_node('Connecting').hide()
	multiplayer.server_disconnected.connect(func():
		#var multiplayer_peer = multiplayer.multiplayer_peer
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		peer.close()
		GameManager.Players = {}
		Game.game_in_progress = true
		UI.in_menu = true
		UI.in_main_menu = true
		UI.in_server_browser = false)
	#add_player(peer_id) #.rpc_id(1, peer_id)

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
	#print('got player info: username: ', username, ' id: ', id)
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
#@rpc('any_peer')
#func clear_player_information():
	#GameManager.Players = {}

func _on_host_pressed():
	if ServerBrowserUI.get_node('UsernameBox').text.is_empty(): return
	GameManager.print_debug_msg('host pressed')
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT)
	if error != OK:
		OS.alert('Cannot host: Error code ' + str(error))
		return
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		OS.alert('Failed to start server')
		return
	#peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)
	send_player_information(ServerBrowserUI.get_node('UsernameBox').text, multiplayer.get_unique_id())
	ServerBrowser.broadcast(ServerBrowserUI.get_node('UsernameBox').text + "'s server")
	#start_game()
	UI.in_menu = false
	UI.in_server_browser = false
	##host doesnt get a character on host pressed
	add_player()
	Game.start_game()

func join_by_ip(ip):
	if ServerBrowserUI.get_node('UsernameBox').text.is_empty(): return
	GameManager.print_debug_msg('trying to join by ip: ' + ip)
	peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, PORT)
	#GameManager.print_debug_msg("Connection status: " + con[peer.get_connection_status()])
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		OS.alert('Failed to start client')
		return
	#peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)
	#print('multiplayer peers: ', multiplayer.get_peers())
	#start_game()
	UI.in_menu = false
	UI.in_server_browser = false
	UI.get_node('Connecting').show()

func quit_server():
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	GameManager.Players = {}
	Game.game_in_progress = true
	UI.in_menu = true
	UI.in_server_browser = false
	UI.in_main_menu = true
	if multiplayer.is_server():
		ServerBrowser.stop_broadcast()
		for player in get_tree().get_nodes_in_group('Player'):
			player.queue_free()
		for bot in get_tree().get_nodes_in_group('Bot'):
			bot.queue_free()

#func start_game():
	#UI.in_menu = false

	#ServerBrowserUI.hide()
#func end_game():
	#UI.in_menu = true

func start_singleplayer():
	UI.in_menu = false
	UI.in_main_menu = false
	GameManager.Players[1] = {
		'username': ServerBrowserUI.get_node('UsernameBox').text,
		'id': 1,
	}
	GameManager.Players[2] = {
		'username': 'Computer',
		'id': 2,
	}
	var plr_char = add_player()
	add_bot(plr_char)
	Game.start_game()

#@rpc('any_peer')
func add_player(id: int = 1):
	#if true: return
	GameManager.print_debug_msg('adding player ' + str(id) + ' by ' + str(multiplayer.get_unique_id()))
	if Level.get_node('Players').has_node(str(id)):
		return
	var character = preload("res://prefabs/Player.tscn").instantiate()
	character.player_id = id
	#character.username = GameManager.Players[id].username
	#character.get_node('Control/Username').text = GameManager.Players[id].username
	character.name = str(id)
	#GameManager.print_debug_msg('trying to get plr username: ' + str(GameManager.Players[id]['username']))
	var num = 1 if id == 1 else 2
	var spawn_point = Level.get_node('World/Player' + str(num) + 'Spawn')
	character.position = spawn_point.position
	character.rotation = spawn_point.rotation
	Level.get_node('Players').add_child(character, true)
	Game.update_score_text_for_all.rpc()
	return character
	#for player in get_tree().get_nodes_in_group('Player'):
		#var plr_id = str(player.name).to_int()
		#if plr_id == 1:
			#Game.update_score_text()
		#else:
			#Game.update_score_text.rpc_id(plr_id)
	#if id != 1:
		#Game.update_score_text.rpc_id(id)
	#character.set_username.rpc_id(id, GameManager.Players[id].username)

func add_bot(player_char):
	var character = preload("res://prefabs/Bot.tscn").instantiate()
	character.player = player_char
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
	if peer:
		var status = peer.get_connection_status()
		GameManager.set_connection_status_text('Connection status: ' + con[status])
	else:
		GameManager.set_connection_status_text('Connection status: -')

#func del_player(id: int):
	#if not Level.get_node('World/Players').has_node(str(id)):
		#return
	#Level.get_node('World/Players').get_node(str(id)).queue_free()
