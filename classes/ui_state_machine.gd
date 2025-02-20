class_name UI_State extends Node

var ui

var in_menu : State = State.new(true)
var in_main_menu : State = State.new(true)
var editing_username : State = State.new(true)
var in_server_browser : State = State.new(false)
var in_server_lobby : State = State.new(false)
var entering_port : State = State.new(false)
var showing_message : State = State.new(false)
var in_game_menu : State = State.new(false)
var showing_leaderboard : State = State.new(false)
var showing_game_ui : State = State.new(false)

func _init(_ui, Network):
	print('Initializing ', _ui, ' state machine')

	ui = _ui

	ui.get_node('MainMenu/Username').show()
	ui.get_node('MainMenu/Menu').hide()
	ui.get_node('MainMenu/Port').hide()
	ui.get_node('MainMenu').show()
	
	ui.get_node('CurrentUsername').hide()
	ui.get_node('ServerBrowser').hide()
	ui.get_node('GameUI').hide()
	ui.get_node('Menu').hide()
	ui.get_node('GameResult').hide()
	ui.get_node('GameControls').hide()
	ui.get_node('Connecting').hide()
	ui.get_node('Lobby').hide()
	ui.get_node('Message').hide()
	ui.get_node('Leaderboard').hide()

	in_menu.state_changed.connect(func(_old_state, new_state, _args):
		ui.set_physics_process(new_state)
		ui.menu_camera_pivot.get_node('MenuCamera').set_current(new_state)
		ui.get_node('CurrentUsername').visible = new_state
		if new_state:
			# ui.get_node('GameUI').hide()
			showing_game_ui.set_state(false)
			ui.get_node('Menu').hide()
			ui.get_node('GameResult').hide()
			ui.get_node('GameControls').hide()
			ui.get_node('Connecting').hide()
			ui.player_camera.set_current(false)
		)
	
	in_main_menu.state_changed.connect(func(_old_state, new_state, _args):
		ui.get_node('MainMenu').visible = new_state
		ui.get_node('CurrentUsername').visible = new_state
		if new_state:
			ui.get_node('MainMenu/Menu').show()
			ui.get_node('MainMenu/Username').hide()
			ui.get_node('MainMenu/Port').hide()
		)

	editing_username.state_changed.connect(func(_old_state, new_state, _args):
		in_main_menu.set_state(true)
		in_server_browser.set_state(false)
		ui.get_node('CurrentUsername').visible = not new_state
		ui.get_node('MainMenu/Menu').visible = not new_state
		ui.get_node('MainMenu/Username').visible = new_state
		)

	in_server_browser.state_changed.connect(func(_old_state, new_state, _args):
		ui.get_node('ServerBrowser').visible = new_state
		if new_state:
			ui.get_node('ServerBrowser/PortPanel/PortText').text = 'Порт: ' + str(ui.Network.PORT)
			ui.ServerBrowser.listenPort = ui.Network.PORT + 1
			ui.ServerBrowser.listen_to_broadcast()
		else:
			ui.ServerBrowser.stop_listen()
		)
	
	in_server_lobby.state_changed.connect(func(_old_state, new_state, args):
		if new_state:
			ui.get_node('Lobby/StartGame').disabled = not args.is_host
		ui.get_node('Lobby').visible = new_state
		)

	entering_port.state_changed.connect(func(_old_state, new_state, _args):
		in_main_menu.set_state(new_state)
		if new_state:
			ui.get_node('CurrentUsername').visible = false
		ui.get_node('MainMenu/Port').visible = new_state
		ui.get_node('MainMenu/Menu').visible = not new_state
		in_server_browser.set_state(not new_state)
		)
	
	showing_message.state_changed.connect(func(_old_state, new_state, _args):
		ui.get_node('Message').visible = new_state
		ui.get_node('MainMenu/Menu').visible = not new_state
		)
	
	in_game_menu.state_changed.connect(func(_old_state, new_state, _args):
		ui.get_node('Menu').visible = new_state
		if Game.current_game_type == Game.game_type.SINGLEPLAYER:
			var match_data = Network.Matches[0]
			if new_state:
				match_data.status = Network.match_status_type.PAUSED
			else:
				match_data.status = Network.match_status_type.IN_PROGRESS
		)
	
	showing_leaderboard.state_changed.connect(func(_old_state, new_state, show_result):
		ui.get_node('Leaderboard').visible = new_state
		# ui.get_node('GameUI').visible = not new_state
		showing_game_ui.set_state(not new_state)
		ui.get_node('Leaderboard/Panel/Results').visible = show_result
		ui.get_node('Leaderboard/Panel/Score').visible = not show_result
		if new_state:
			ui.get_node('Leaderboard/Panel/ReadyCheck').hide()
		)
	
	showing_game_ui.state_changed.connect(func(_old_state, new_state, _args):
		ui.get_node('GameUI').visible = new_state
		)
