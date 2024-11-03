extends Control

@onready var ServerBrowser = get_tree().get_first_node_in_group('ServerBrowser_root')

@export var menu_camera_pivot : Node
@export var player_camera : Node
@export var title_label : Node
var title_tween = null
var title_rot_deg = 1
var title_rot_time = 1

@export var in_menu : bool = true :
	set(value):
		in_menu = value
		set_physics_process(value)
		menu_camera_pivot.get_node('MenuCamera').set_current(value)
		if value:
			get_node('GameUI').hide()
			get_node('Menu').hide()
			get_node('GameResult').hide()
			get_node('Connecting').hide()
			player_camera.set_current(false)
@export var in_main_menu : bool = true :
	set(value):
		in_main_menu = value
		get_node('MainMenu').visible = value
@export var in_server_browser : bool = false :
	set(value):
		in_server_browser = value
		get_node('ServerBrowser').visible = value
		if value:
			ServerBrowser.listen_to_broadcast()
		else:
			ServerBrowser.stop_listen()
		#menu_camera_pivot.get_node('MenuCamera').set_current(value)
		#if value == true:
			#get_node('GameUI').hide()
			#get_node('Menu').hide()
			#get_node('GameResult').hide()
			#get_node('Connecting').hide()
			#player_camera.set_current(false)

func _ready():
	get_node('MainMenu').show()
	get_node('ServerBrowser').hide()
	get_node('GameUI').hide()
	get_node('Menu').hide()
	get_node('GameResult').hide()
	get_node('Connecting').hide()
	get_node('ServerBrowser/Back').pressed.connect(_on_server_browser_back_pressed)

func _enter_tree():
	title_label.rotation = deg_to_rad(-title_rot_deg)
	title_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	title_tween.tween_property(title_label, 'rotation', deg_to_rad(title_rot_deg), title_rot_time)
	title_tween.chain().tween_property(title_label, 'rotation', deg_to_rad(-title_rot_deg), title_rot_time)

func _on_back_pressed():
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	GameManager.Players = {}
	Game.game_in_progress = true
	in_menu = true
	in_server_browser = false
	in_main_menu = true
	if multiplayer.is_server():
		ServerBrowser.stop_broadcast()
		for player in get_tree().get_nodes_in_group('Player'):
			player.queue_free()

func _on_server_browser_back_pressed():
	in_main_menu = true
	in_server_browser = false

func _on_close_pressed():
	get_node('Menu').hide()

func _on_title_visibility_changed():
	if title_label.visible:
		title_label.rotation = deg_to_rad(-title_rot_deg)
		title_tween.play()
	else:
		title_tween.stop()

func _on_singleplayer_pressed():
	pass # Replace with function body.

func _on_multiplayer_pressed():
	in_main_menu = false
	in_server_browser = true

func _on_exit_pressed():
	get_tree().quit()

func _physics_process(_delta):
	if Game.window_focus:
		menu_camera_pivot.rotation.y += 0.0005
