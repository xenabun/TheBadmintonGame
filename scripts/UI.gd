extends Control

var ui_state_class = load("res://classes/ui_state.gd")

@export var menu_camera_pivot : Node
@export var player_camera : Node
@export var title_label : Node
@export var username_box : Node
@export var lobby_player_list : Node
@export var Network : Node
@export var ServerBrowser : Node



@export var in_menu : bool = true :
	set(value):
		in_menu = value
		set_physics_process(value)
		menu_camera_pivot.get_node('MenuCamera').set_current(value)
		get_node('CurrentUsername').visible = value
		if value:
			get_node('GameUI').hide()
			get_node('Menu').hide()
			get_node('GameResult').hide()
			get_node('GameControls').hide()
			get_node('Connecting').hide()
			player_camera.set_current(false)
@export var in_main_menu : bool = true :
	set(value):
		in_main_menu = value
		get_node('MainMenu').visible = value
		get_node('CurrentUsername').visible = value
		if value:
			get_node('MainMenu/Menu').show()
			get_node('MainMenu/Username').hide()
			get_node('MainMenu/Port').hide()
@export var editing_username : bool = true :
	set(value):
		editing_username = value
		in_main_menu = true
		in_server_browser = false
		get_node('CurrentUsername').visible = not value
		get_node('MainMenu/Menu').visible = not value
		get_node('MainMenu/Username').visible = value
@export var in_server_browser : bool = false :
	set(value):
		in_server_browser = value
		get_node('ServerBrowser').visible = value
		if value:
			get_node('ServerBrowser/PortText').text = 'Порт: ' + str(Network.PORT)
			ServerBrowser.listenPort = Network.PORT + 1
			ServerBrowser.listen_to_broadcast()
		else:
			ServerBrowser.stop_listen()
@export var in_server_lobby : bool = false :
	set(value):
		in_server_lobby = value
		get_node('Lobby').visible = value

var title_tween
var title_rot_deg = 1
var title_rot_time = 1

func _ready():
	var ui_state = ui_state_class.new()
	ui_state.init(self)

	# get_node('MainMenu/Username').show()
	# get_node('MainMenu/Menu').hide()
	# get_node('MainMenu/Port').hide()
	# get_node('MainMenu').show()
	
	# get_node('CurrentUsername').hide()
	# get_node('ServerBrowser').hide()
	# get_node('GameUI').hide()
	# get_node('Menu').hide()
	# get_node('GameResult').hide()
	# get_node('GameControls').hide()
	# get_node('Connecting').hide()
	# get_node('Lobby').hide()
	
	get_node('ServerBrowser/Back').pressed.connect(_on_server_browser_back_pressed)

func _enter_tree():
	title_label.rotation = deg_to_rad(-title_rot_deg)
	title_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	title_tween.tween_property(title_label, 'rotation', deg_to_rad(title_rot_deg), title_rot_time)
	title_tween.chain().tween_property(title_label, 'rotation', deg_to_rad(-title_rot_deg), title_rot_time)

func clear_lobby_player_list():
	for child in lobby_player_list.get_children():
		child.queue_free()
func update_lobby_player_list():
	# GameManager.print_debug_msg('update lobby player list called')
	clear_lobby_player_list()
	# print(GameManager.Players)
	for i in GameManager.Players:
		var player_info = GameManager.Players[i]
		# print(player_info)
		var player_label = preload("res://prefabs/player_label.tscn").instantiate()
		player_label.text = player_info.username
		lobby_player_list.add_child(player_label)

func _on_game_exit_pressed():
	Network.quit_server()

func _on_server_browser_back_pressed():
	in_main_menu = true
	in_server_browser = false

func _on_pause_menu_close():
	get_node('Menu').hide()
	if Game.current_game_type == Game.game_type.SINGLEPLAYER:
		Game.game_in_progress = true

func _on_title_visibility_changed():
	if title_label.visible:
		title_label.rotation = deg_to_rad(-title_rot_deg)
		title_tween.play()
	else:
		title_tween.stop()
		
func _on_username_confirm_pressed():
	if get_node('MainMenu/Username/UsernameBox').text.is_empty(): return
	editing_username = false
	username_box.text = get_node('MainMenu/Username/UsernameBox').text
func _on_username_change_pressed():
	editing_username = true

func _on_singleplayer_pressed():
	Network.start_singleplayer()

func _on_multiplayer_pressed():
	get_node('CurrentUsername').hide()
	get_node('MainMenu/Menu').hide()
	get_node('MainMenu/Port').show()

func _on_port_menu_close_pressed():
	get_node('CurrentUsername').show()
	get_node('MainMenu/Port').hide()
	get_node('MainMenu/Menu').show()

func _on_port_confirm():
	var port_text = get_node('MainMenu/Port/VBoxContainer/LineEdit').text
	var port_num = port_text.to_int()
	if port_num and port_num >= 1024 and port_num <= 49151:
		Network.PORT = port_num
		in_main_menu = false
		in_server_browser = true
		get_node('MainMenu/Port').hide()

func _on_controls_close():
	get_node('GameControls').hide()

func _on_app_exit_pressed():
	get_tree().quit()

func _physics_process(_delta):
	if Game.window_focus:
		menu_camera_pivot.rotation.y += 0.0005
