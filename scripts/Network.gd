extends Node

const ADDRESS = '127.0.0.1'

enum server_state_type {
	NONE,
	LOBBY,
	MATCH
}
enum player_state_type {
	NONE,
	SPECTATOR,
	PLAYER
}

@export var PORT = 5000
@export var Level : Node
@export var UI : Node
@export var ServerBrowser : Node
@export var ServerBrowserUI : Node

@export var server_state : server_state_type = server_state_type.NONE
@export var Players : Dictionary = {}

var peer

func _ready():
	multiplayer.server_relay = false
	
	if not multiplayer.is_server(): return
	
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_disconnected)
	multiplayer.connected_to_server.connect(connected_to_server)
	multiplayer.connection_failed.connect(connection_failed)
	ServerBrowser.join_server.connect(join_by_ip)

func update_lobby_player_list_for_all():
	for i in Players:
		if multiplayer.get_unique_id() == i:
			UI.update_lobby_player_list(Players)
		else:
			UI.update_lobby_player_list.rpc_id(i, Players)

@rpc('any_peer')
func add_player_data(player_id, username):
	if not Players.has(player_id):
		Players[player_id] = {
			'id': player_id,
			'username': username,
			'state': player_state_type.NONE,
		}
		Game.update_score_text_for_all.rpc()
		update_lobby_player_list_for_all()

func del_player_data(player_id):
	if not Players.has(player_id): return
	Players.erase(player_id)
	update_lobby_player_list_for_all()

func remove_player(id):
	if multiplayer.is_server():
		Level.get_node('World/Ball').set_multiplayer_authority(1)
		del_player_data(id)
		Game.update_score_text_for_all.rpc()
		for player in get_tree().get_nodes_in_group('Player'):
			if str(player.name) == str(id):
				player.queue_free()

func kick_peer(id):
	kicked.rpc_id(id)
	remove_player(id)

func peer_connected(id):
	Game.print_debug_msg('Player connected ' + str(id))
	if multiplayer.is_server() and server_state != server_state_type.LOBBY:
		kick_peer(id)

func peer_disconnected(id):
	Game.print_debug_msg('Player disconnected ' + str(id))
	remove_player(id)

##client
func connected_to_server():
	Game.print_debug_msg('Connected to server')
	var peer_id = multiplayer.get_unique_id()
	add_player_data.rpc_id(1, peer_id, UI.username_box.text)
	UI.get_node('Connecting').hide()
	multiplayer.server_disconnected.connect(quit_server)

##client
func connection_failed():
	Game.print_debug_msg('Connection failed')
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peer.close()
	Players = {}
	Game.game_in_progress = true
	UI.state.in_menu.set_state(true)
	UI.state.in_main_menu.set_state(false)
	UI.state.in_server_browser.set_state(true)
	UI.state.in_server_lobby.set_state(false)

func _on_host_pressed():
	Game.print_debug_msg('host pressed')
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
	ServerBrowser.broadcastPort = PORT + 2
	ServerBrowser.broadcast("Сервер " + UI.username_box.text + "-а")
	server_state = server_state_type.LOBBY
	UI.state.in_server_lobby.set_state(true, {is_host = true})
	UI.state.in_server_browser.set_state(false)

	add_player_data(1, UI.username_box.text)

func _on_start_game_pressed():
	if not multiplayer.is_server(): return

	ServerBrowser.stop_broadcast()
	Game.start_game()
	for i in Players:
		if multiplayer.get_unique_id() == i:
			UI.close_lobby_player_list()
		else:
			UI.close_lobby_player_list.rpc_id(i)

func join_by_ip(ip):
	Game.print_debug_msg('trying to join by ip: ' + ip)
	peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, PORT)
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		OS.alert('Failed to start client')
		return
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	Game.current_game_type = Game.game_type.MULTIPLAYER
	multiplayer.set_multiplayer_peer(peer)
	UI.state.in_server_lobby.set_state(true, {is_host = false})
	UI.state.in_server_browser.set_state(false)
	UI.get_node('Connecting').show()

@rpc('any_peer')
func kicked():
	quit_server()
	UI.show_message("Вы были выгнаны из сервера")

func quit_server():
	if multiplayer.server_disconnected.is_connected(quit_server):
		multiplayer.server_disconnected.disconnect(quit_server)
	Game.current_game_type = Game.game_type.NONE
	server_state = server_state_type.NONE
	if peer:
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	Players = {}
	Game.game_in_progress = true
	Game.ball.set_ball_ready()
	Game.ball.reset_ball()
	UI.state.in_menu.set_state(true)
	UI.state.in_main_menu.set_state(true)
	UI.state.in_server_lobby.set_state(false)
	UI.state.in_server_browser.set_state(false)
	if multiplayer.is_server():
		ServerBrowser.stop_broadcast()
		for player in get_tree().get_nodes_in_group('Player'):
			player.queue_free()
		for bot in get_tree().get_nodes_in_group('Bot'):
			bot.queue_free()

func start_singleplayer():
	Game.current_game_type = Game.game_type.SINGLEPLAYER
	UI.state.in_menu.set_state(false)
	UI.state.in_main_menu.set_state(false)
	var bot_username = 'Компьютер'
	add_player_data(1, UI.username_box.text)
	add_player_data(2, bot_username)
	var plr_char = add_player()
	add_bot(plr_char, bot_username)
	Game.start_game()

func add_player(id: int = 1):
	Game.print_debug_msg('adding player ' + str(id) + ' by ' + str(multiplayer.get_unique_id()))
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
	character.Level = Level
	character.get_node('Username').text = bot_username
	var spawn_point = Level.get_node('World/Player2Spawn')
	character.position = spawn_point.position
	character.rotation = spawn_point.rotation
	Level.get_node('Players').add_child(character, true)
	Game.update_score_text()

func _process(_delta):
	if not Game.debug:
		set_process(false)
		return
	
	if peer:
		var status = peer.get_connection_status()
		Game.set_connection_status_text('Connection status: ' + [
			'CONNECTION_DISCONNECTED',
			'CONNECTION_CONNECTING',
			'CONNECTION_CONNECTED',
		][status])
	else:
		Game.set_connection_status_text('Connection status: -')
