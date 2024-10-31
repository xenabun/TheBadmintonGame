extends Node

const ADDRESS = '127.0.0.1'
const PORT = 49664 #8910 #49666
var peer

@onready var Level = get_tree().get_first_node_in_group('Level_root')
@onready var UI = get_tree().get_first_node_in_group('UI_root')
@onready var ServerBrowserUI = UI.get_node('ServerBrowser')
@onready var ServerBrowser = get_tree().get_first_node_in_group('ServerBrowser_root')

func _ready():
	multiplayer.server_relay = false
	ServerBrowserUI.host_pressed.connect(_on_host_pressed)
	
	if not multiplayer.is_server():
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
	Level.get_node('World/Ball').set_multiplayer_authority(1)
	del_player_information(id)
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
@rpc("any_peer")
func disconnect_peer():
	multiplayer.multiplayer_peer.disconnect_peer(1)

##client
func connected_to_server():
	GameManager.print_debug_msg('Connected to server')
	var peer_id = multiplayer.get_unique_id()
	GameManager.Players[peer_id] = {
		'username': ServerBrowserUI.get_node('UsernameBox').text,
		'id': peer_id,
	}
	send_player_information.rpc_id(1, ServerBrowserUI.get_node('UsernameBox').text, peer_id)
	multiplayer.server_disconnected.connect(func():
		#var multiplayer_peer = multiplayer.multiplayer_peer
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
		peer.close()
		GameManager.Players = {}
		UI.in_menu = true)
	#add_player(peer_id) #.rpc_id(1, peer_id)

##client
func connection_failed():
	GameManager.print_debug_msg('Connection failed')

@rpc('any_peer')
func send_player_information(username, id):
	#print('got player info: username: ', username, ' id: ', id)
	if !GameManager.Players.has(id):
		GameManager.Players[id] = {
			'username': username,
			'id': id,
		}
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
@rpc('any_peer')
func clear_player_information():
	GameManager.Players = {}

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
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)
	send_player_information(ServerBrowserUI.get_node('UsernameBox').text, multiplayer.get_unique_id())
	ServerBrowser.broadcast(ServerBrowserUI.get_node('UsernameBox').text + "'s server")
	start_game()
	##host doesnt get a character on host pressed
	add_player()

func join_by_ip(ip):
	if ServerBrowserUI.get_node('UsernameBox').text.is_empty(): return
	
	GameManager.print_debug_msg('trying to join by ip: ' + ip)
	peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, PORT)
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		OS.alert('Failed to start client')
		return
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)
	#print('multiplayer peers: ', multiplayer.get_peers())
	start_game()

func start_game():
	#ServerBrowserUI.hide()
	UI.in_menu = false
#func end_game():
	#UI.in_menu = true

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
	#character.set_username.rpc_id(id, GameManager.Players[id].username)

func del_player(id: int):
	if not Level.get_node('World/Players').has_node(str(id)):
		return
	Level.get_node('World/Players').get_node(str(id)).queue_free()
