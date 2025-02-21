extends Node

const ADDRESS : String = '127.0.0.1'

enum server_state_type {
	NONE,
	LOBBY,
	MATCH,
}
enum player_state_type {
	NONE,
	SPECTATOR,
	PLAYER,
}
enum match_status_type {
	IN_PROGRESS,
	PAUSED,
	FINISHED,
}

@export var PORT : int = 3333
@export var Level : Node
@export var UI : Node
@export var ServerBrowser : Node
@export var ServerBrowserUI : Node

@export var server_state : server_state_type = server_state_type.NONE
@export var Matches : Dictionary = {}
@export var Leaderboard : Dictionary = {}
@export var Players : Dictionary = {}
@export var Balls : Dictionary = {}

var peer

func _ready():
	multiplayer.server_relay = true
	
	if not multiplayer.is_server(): return
	
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_disconnected)
	multiplayer.connected_to_server.connect(connected_to_server)
	multiplayer.connection_failed.connect(connection_failed)
	ServerBrowser.join_server.connect(join_by_ip)

func find_first_player_by_match_id(match_id):
	for i in Players:
		var pdata = Players[i]
		if pdata.has('match_id') and pdata.has('num') and pdata.match_id == match_id:
			return pdata

func find_player_by_match_id_with_num(match_id, num):
	for i in Players:
		var pdata = Players[i]
		if pdata.has('match_id') and pdata.has('num') and pdata.match_id == match_id and pdata.num == num:
			return pdata

func update_lobby_player_list_for_all():
	if Game.current_game_type == Game.game_type.SINGLEPLAYER: return
	UI.update_lobby_player_list.rpc(Players)

@rpc('any_peer', 'call_local')
func set_match_id(player_id, match_id):
	Players[player_id].match_id = match_id

@rpc('any_peer')
func add_player_data(player_id, username, is_bot):
	if Players.has(player_id):return
	Players[player_id] = {
		'id': player_id,
		'username': username,
		'state': player_state_type.NONE,
		'is_bot': is_bot,
	}
	update_lobby_player_list_for_all()

func del_player_data(player_id):
	if not Players.has(player_id): return
	Players.erase(player_id)
	update_lobby_player_list_for_all()

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
	add_player_data.rpc_id(1, peer_id, UI.username_box.text, false)
	UI.get_node('Connecting').hide()
	multiplayer.server_disconnected.connect(quit_server)

##client
func connection_failed():
	Game.print_debug_msg('Connection failed')
	quit_server()
	UI.show_message("Не удалось установить соединение")

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

	add_player_data(1, UI.username_box.text, false)

func _on_start_game_pressed():
	if not multiplayer.is_server(): return
	if Players.size() <= 1:
		OS.alert('Необходимо минимум 2 игрока для начала игры')
		return

	ServerBrowser.stop_broadcast()
	Game.start_game()
	UI.close_lobby_player_list.rpc()

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

func start_singleplayer():
	Game.current_game_type = Game.game_type.SINGLEPLAYER
	UI.state.in_menu.set_state(false)
	UI.state.in_main_menu.set_state(false)
	var bot_username = 'Компьютер'
	add_player_data(1, UI.username_box.text, false)
	add_player_data(2, bot_username, true)
	Game.start_game()

@rpc('any_peer')
func kicked():
	quit_server()
	UI.show_message("Вы были исключены")

func quit_server():
	multiplayer.multiplayer_peer.disconnect_peer(1)
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if peer: peer.close()
	
	if multiplayer.server_disconnected.is_connected(quit_server):
		multiplayer.server_disconnected.disconnect(quit_server)
	Game.current_game_type = Game.game_type.NONE
	server_state = server_state_type.NONE
	Players = {}
	Balls = {}
	Matches = {}
	Leaderboard = {}
	UI.leaderboard_clear()
	UI.state.showing_leaderboard.set_state(false, false)
	UI.state.in_menu.set_state(true)
	UI.state.in_main_menu.set_state(true)
	UI.state.in_server_lobby.set_state(false)
	UI.state.in_server_browser.set_state(false)
	# if multiplayer.is_server():
	ServerBrowser.stop_broadcast()
	for ball in get_tree().get_nodes_in_group('Ball'):
		ball.queue_free()
	for player in get_tree().get_nodes_in_group('Player'):
		player.queue_free()
	for spectator in get_tree().get_nodes_in_group('Spectator'):
		spectator.queue_free()
	for bot in get_tree().get_nodes_in_group('Bot'):
		bot.queue_free()

@rpc('any_peer', 'call_local')
func setup_player(character_name, data):
	var character = Level.get_node('Players/' + character_name)
	character.position = data.position
	character.rotation = data.rotation

func add_player(id : int = 1, num : int = 1):
	if Level.get_node('Players').has_node(str(id)): return
	Game.print_debug_msg('adding player ' + str(id) + ' by ' + str(multiplayer.get_unique_id()))

	var character = preload("res://prefabs/Player.tscn").instantiate()
	character.name = str(id)
	var spawn_point = Level.get_node('World/Player' + str(num) + 'SpawnEven')
	Level.get_node('Players').add_child(character, true)
	setup_player.rpc_id(id, str(id), {
		position = spawn_point.position,
		rotation = spawn_point.rotation,
	})

	return character

func remove_player(id):
	_remove_player.rpc(id)
	if not multiplayer.is_server(): return
	var match_id
	var pdata = Players[id]
	if pdata.has('match_id'):
		match_id = pdata.match_id
	del_player_data(id)
	if match_id:
		var ball = Game.get_ball_by_match_id(match_id)
		if ball:
			ball.set_multiplayer_authority(1)
	Game.update_score_text_for_all()

@rpc('any_peer', 'call_local')
func _remove_player(id):
	if Level.get_node('Players').has_node(str(id)):
		var player = Level.get_node('Players/' + str(id))
		player.queue_free()
	if Level.get_node('Spectators').has_node(str(id)):
		var spectator = Level.get_node('Spectators/' + str(id))
		spectator.queue_free()

func add_spectator(id: int = 1):
	if Level.get_node('Spectators').has_node(str(id)): return
	Game.print_debug_msg('adding spectator ' + str(id) + ' by ' + str(multiplayer.get_unique_id()))

	var spectator = preload("res://prefabs/Spectator.tscn").instantiate()
	spectator.name = str(id)
	Level.get_node('Spectators').add_child(spectator, true)

func add_bot(bot_username):
	var character = preload("res://prefabs/Bot.tscn").instantiate()
	character.name = '2'
	character.player = Level.get_node('Players/1')
	character.Level = Level
	character.get_node('Username').text = bot_username
	var spawn_point = Level.get_node('World/Player2Spawn')
	character.position = spawn_point.position
	character.rotation = spawn_point.rotation
	Level.get_node('Players').add_child(character, true)
	Game.update_score_text()

func add_ball(match_id):
	if Balls.has(match_id): return
	Game.print_debug_msg('adding ball with match id: ' + str(match_id) + ' by ' + str(multiplayer.get_unique_id()))

	var ball = preload("res://prefabs/Ball.tscn").instantiate()
	ball.name = str(match_id)
	ball.match_id = match_id
	Level.get_node('Balls').add_child(ball, true)
	Balls[match_id] = {
		'match_id': match_id
	}

func remove_ball(match_id):
	if not Balls.has(match_id): return
	if Game.current_game_type == Game.game_type.SINGLEPLAYER:
		Level.get_node('Players/2').ball = null
	if Level.get_node('Balls').has_node(str(match_id)):
		var ball = Level.get_node('Balls/' + str(match_id))

		var multiplayer_authority = ball.get_multiplayer_authority()
		if multiplayer_authority != multiplayer.get_unique_id():
			ball.reset_authority.rpc_id(multiplayer_authority)

		ball.queue_free()
	Balls.erase(match_id)

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
