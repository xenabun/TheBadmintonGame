extends Node

signal join_server(ip)

@export var listenPort : int
@export var broadcastPort : int
@export var broadcastAddress : String = '255.255.255.255'
@export var broadcastTimer : Timer
@export var server_card_prefab : PackedScene
@export var UI : Node
@export var ServerBrowserUI : Node
@export var Network : Node

var roomInfo = {"name": "room name", "player_count": 0}
var broadcaster : PacketPeerUDP
var listener : PacketPeerUDP

func _ready():
	set_process(false)

func listen_to_broadcast():
	listener = PacketPeerUDP.new()
	var status = listener.bind(listenPort)
	if status == OK:
		Game.print_debug_msg('Bound to listen port ' + str(listenPort) + ' successful')
		Game.set_listen_port_bound_text('listen port bound: true')
	else:
		Game.print_debug_msg('Failed to bind to listen port')
		Game.set_listen_port_bound_text('listen port bound: false')
	set_process(true)

func broadcast(room_name):
	roomInfo.name = room_name
	roomInfo.player_count = Network.Players.size()
	
	broadcaster = PacketPeerUDP.new()
	broadcaster.set_dest_address(broadcastAddress, listenPort)
	broadcaster.set_broadcast_enabled(true)
	
	var status = broadcaster.bind(broadcastPort)
	
	if status == OK:
		Game.print_debug_msg('Bound to broadcast port ' + str(broadcastPort) + ' successful')
	else:
		Game.print_debug_msg('Failed to bind to broadcast port')
	
	broadcastTimer.start()

func get_player_count_string(count):
	if int(count) % 10 <= 1:
		return str(count) + ' игрок'
	elif int(count) % 10 >= 2 and int(count) % 10 <= 4:
		return str(count) + ' игрока'
	else:
		return str(count) + ' игроков'

func _process(_delta):
	if not listener: return
	
	if listener.get_available_packet_count() > 0:
		var server_ip = listener.get_packet_ip()
		var packet = listener.get_packet()
		if server_ip.is_empty(): return
		
		var server_port = listener.get_packet_port()
		var data = packet.get_string_from_utf8()
		var pRoomInfo = JSON.parse_string(data)
		
		for i in ServerBrowserUI.get_node('ServerList/ScrollContainer/VBoxContainer').get_children():
			if i.ip == server_ip:
				i.port = server_port
				i.player_count = pRoomInfo.player_count
				i.text = 'Загрузка' if int(server_port) == 0 else pRoomInfo.name + '\n' + server_ip
				i.get_node('PlayerCount').text = get_player_count_string(pRoomInfo.player_count) # + '/' + str(i.max_player_count)
				i.restart_timer.emit()
				return
		
		var server_card = server_card_prefab.instantiate()
		server_card.name = pRoomInfo.name
		server_card.ip = server_ip
		server_card.port = server_port
		# server_card.max_player_count = %PlayerSpawner.get_spawn_limit()
		server_card.player_count = pRoomInfo.player_count
		server_card.text = 'Загрузка' if int(server_port) == 0 else pRoomInfo.name + '\n' + server_ip
		server_card.get_node('PlayerCount').text = get_player_count_string(pRoomInfo.player_count) # + '/' + str(server_card.max_player_count)
		ServerBrowserUI.get_node('ServerList/ScrollContainer/VBoxContainer').add_child(server_card)
		server_card.join_server.connect(join_by_ip)

func _on_broadcast_timer_timeout():
	roomInfo.player_count = Network.Players.size()
	var data = JSON.stringify(roomInfo)
	var packet = data.to_utf8_buffer()
	broadcaster.put_packet(packet)

func stop_broadcast():
	broadcastTimer.stop()
	if broadcaster != null:
		broadcaster.close()
		broadcaster = null
func stop_listen():
	if listener != null:
		listener.close()
		listener = null
		set_process(false)
		Game.print_debug_msg('Listener closed')
		Game.set_listen_port_bound_text('listen port bound: -')
func clean_up():
	stop_listen()
	stop_broadcast()
func _exit_tree():
	clean_up()

func join_by_ip(ip):
	join_server.emit(ip)
