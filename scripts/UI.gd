extends Control

@onready var Network = get_tree().get_first_node_in_group('Network_root')
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
		get_node('CurrentUsername').visible = value
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
			ServerBrowser.listen_to_broadcast()
		else:
			ServerBrowser.stop_listen()

func _ready():
	get_node('MainMenu/Username').show()
	get_node('MainMenu/Menu').hide()
	get_node('MainMenu').show()
	
	get_node('CurrentUsername').hide()
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
	Network.quit_server()

func _on_server_browser_back_pressed():
	in_main_menu = true
	in_server_browser = false

func _on_close_pressed():
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
	get_node('CurrentUsername/VBoxContainer/Username').text = get_node('MainMenu/Username/UsernameBox').text

func _on_username_change_pressed():
	editing_username = true

func _on_singleplayer_pressed():
	Network.start_singleplayer()

func _on_multiplayer_pressed():
	in_main_menu = false
	in_server_browser = true

func _on_exit_pressed():
	get_tree().quit()

func _physics_process(_delta):
	if Game.window_focus:
		menu_camera_pivot.rotation.y += 0.0005
