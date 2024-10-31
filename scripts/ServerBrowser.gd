extends Node

signal found_server
signal server_removed
signal join_server(ip)

var roomInfo = {"name": "room name", "player_count": 0}
var broadcaster : PacketPeerUDP
var listener : PacketPeerUDP

@export var listenPort : int = 49665 #60989 #8911 #49667
@export var broadcastPort : int = 49666 #60990 #8912 #49668
@export var broadcastAddress : String = '255.255.255.255'
@export var broadcastTimer : Timer
@export var server_card_prefab : PackedScene
@onready var UI = get_tree().get_first_node_in_group('UI_root')
@onready var ServerBrowserUI = UI.get_node('ServerBrowser')

func _ready():
	listen_to_broadcast()
	
func listen_to_broadcast():
	listener = PacketPeerUDP.new()
	var status = listener.bind(listenPort)
	if status == OK:
		GameManager.print_debug_msg('Bound to listen port ' + str(listenPort) + ' successful')
		ServerBrowserUI.get_node('ListenPortBound').text = 'listen port bound: true'
	else:
		GameManager.print_debug_msg('Failed to bind to listen port')
		ServerBrowserUI.get_node('ListenPortBound').text = 'listen port bound: false'

func broadcast(room_name):
	roomInfo.name = room_name
	roomInfo.player_count = GameManager.Players.size()
	
	broadcaster = PacketPeerUDP.new()
	broadcaster.set_broadcast_enabled(true)
	broadcaster.set_dest_address(broadcastAddress, listenPort)
	
	var status = broadcaster.bind(broadcastPort)
	
	if status == OK:
		GameManager.print_debug_msg('Bound to broadcast port ' + str(broadcastPort) + ' successful')
	else:
		GameManager.print_debug_msg('Failed to bind to broadcast port')
	
	broadcastTimer.start()
func stop_broadcast():
	broadcastTimer.stop()
	if broadcaster != null:
		broadcaster.close()

func _process(_delta):
	if listener.get_available_packet_count() > 0:
		var server_ip = listener.get_packet_ip()
		var packet = listener.get_packet()
		if server_ip.is_empty(): return
		
		var server_port = listener.get_packet_port()
		var data = packet.get_string_from_ascii()
		var pRoomInfo = JSON.parse_string(data)
		
		#print('server ip: ', server_ip, ' server port: ', str(server_port))
		#, ' room info: ', str(pRoomInfo))
		
		for i in ServerBrowserUI.get_node('ServerList/ScrollContainer/VBoxContainer').get_children():
			if i.ip == server_ip:
				i.port = server_port
				i.text = 'Loading' if int(server_port) == 0 else pRoomInfo.name
				i.restart_timer.emit()
				return
		
		var server_card = server_card_prefab.instantiate()
		server_card.name = pRoomInfo.name
		server_card.ip = server_ip
		server_card.port = server_port
		server_card.text = 'Loading' if int(server_port) == 0 else pRoomInfo.name
		ServerBrowserUI.get_node('ServerList/ScrollContainer/VBoxContainer').add_child(server_card)
		server_card.join_server.connect(join_by_ip)

func _on_broadcast_timer_timeout():
	#print('Broadcasting game')
	roomInfo.player_count = GameManager.Players.size()
	var data = JSON.stringify(roomInfo)
	var packet = data.to_ascii_buffer()
	broadcaster.put_packet(packet)

func clean_up():
	listener.close()
	broadcastTimer.stop()
	if broadcaster != null:
		broadcaster.close()

func _exit_tree():
	clean_up()

func join_by_ip(ip):
	join_server.emit(ip)
