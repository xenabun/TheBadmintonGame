extends MultiplayerSynchronizer

@onready var UI = get_tree().get_first_node_in_group('UI_root')

@export var direction := Vector3()
@export var player : Node
@export var sprinting : bool = false
@export var stamina : float = PlayerVariables.MAX_STAMINA:
	set(value):
		stamina = value
		player.stamina_bar.value = value
@export var exhausted : bool = false:
	set(value):
		exhausted = value
		player.stamina_bar.get("theme_override_styles/fill").bg_color = Color.html(
				PlayerVariables.STAMINA_BAR_COLOR_LOCKED if value else
				PlayerVariables.STAMINA_BAR_COLOR_NORMAL)
@export var aim_direction : Vector2 = Vector2.ZERO
#@export var action_hold_progress = 1

var action_ready = true
var action_hold = false:
	set(value):
		action_hold = value
		if value == false:
			action_ready = false
			$RacketActive.start()
			$RacketCooldown.start()
			racket_swing.rpc()
			player.get_node('AimArrow').hide()
var action_active = false:
	set(value):
		action_active = value
		racket_area_activate.rpc(value)
var movement_actions = [false, false, false, false] # up right down left
var last_movement_action_pressed = null
var shift_hold = false

@rpc('any_peer', 'call_local')
func racket_area_activate(value):
	player.get_node('RacketArea').monitorable = value
	if Game.debug: player.get_node('RacketArea/CSGBox3D').visible = value

@rpc("any_peer", "call_local")
func throw_ready():
	player.get_node('AnimationTree')['parameters/Throw/request'] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
@rpc("any_peer", "call_local")
func racket_hold():
	player.get_node('AnimationTree')['parameters/RacketHold/request'] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
@rpc("any_peer", "call_local")
func racket_swing():
	player.get_node('AnimationTree')['parameters/RacketHold/request'] = AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT
	player.get_node('AnimationTree')['parameters/RacketSwing/request'] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE

@rpc('any_peer', 'call_local')
func set_throw_power(value):
	player.throw_power = value
@rpc('any_peer', 'call_local')
func set_aim_x(value):
	player.aim_x = value

func _ready():
	var authority = get_multiplayer_authority() == multiplayer.get_unique_id()
	set_process(authority)
	player = get_parent()
	player.get_node('RacketArea/CSGBox3D').hide()
	$RacketHold.wait_time = PlayerVariables.ACTION_HOLD_TIME

func _input(event):
	if get_multiplayer_authority() != multiplayer.get_unique_id(): return
	
	if event.is_action_pressed('ui_cancel'):
		if UI.get_node('GameControls').visible:
			UI.get_node('GameControls').visible = false
		else:
			var menu = UI.get_node('Menu')
			menu.visible = not menu.visible
			if Game.current_game_type == Game.game_type.SINGLEPLAYER:
				Game.game_in_progress = not menu.visible
	
	if not Game.game_in_progress: return
	if UI.get_node('Menu').visible or UI.get_node('GameControls').visible: return
	
	if event.is_action_pressed('action'):
		if Game.ball.ball_ready and Game.game_in_progress:
			var dir = VectorMath.look_vector(player.get_node('RacketArea')).z
			var pos = player.get_node('Ball').global_position
			Game.ball.throw_ball.rpc(Game.get_opponent_peer_id(multiplayer.get_unique_id()),
					pos, dir, aim_direction)
			player.get_node('AimArrow').hide()
			throw_ready.rpc()
		else:
			if action_ready and not action_active:
				action_hold = true
				$RacketHold.start()
				action_active = true
				racket_hold.rpc()
	if event.is_action_released('action') and action_hold:
		$RacketHold.stop()
		action_hold = false
	if event.is_action_pressed('sprint'):
		shift_hold = true
		sprinting = true
	if event.is_action_released('sprint'):
		shift_hold = false
		sprinting = false
	if (event.is_action_pressed("left") or event.is_action_pressed('right') or
			event.is_action_pressed('down') or event.is_action_pressed('up')):
		var current_action
		if event.is_action('left'):
			current_action = 'left'
			movement_actions[3] = true
		elif event.is_action('right'):
			current_action = 'right'
			movement_actions[1] = true
		elif event.is_action('down'):
			current_action = 'down'
			movement_actions[2] = true
		elif event.is_action('up'):
			current_action = 'up'
			movement_actions[0] = true
		if (not sprinting and last_movement_action_pressed != null and
				last_movement_action_pressed == current_action and
				$ActionPressed.time_left > 0):
			sprinting = true
		if not sprinting and last_movement_action_pressed != current_action:
			$ActionPressed.start()
		last_movement_action_pressed = current_action
	if (event.is_action_released("left") or event.is_action_released('right') or
			event.is_action_released('down') or event.is_action_released('up')):
		if event.is_action('left'):
			movement_actions[3] = false
		elif event.is_action('right'):
			movement_actions[1] = false
		elif event.is_action('down'):
			movement_actions[2] = false
		elif event.is_action('up'):
			movement_actions[0] = false
		if (sprinting and movement_actions[0] == false and
				movement_actions[1] == false and
				movement_actions[2] == false and
				movement_actions[3] == false and
				shift_hold == false):
			sprinting = false

func _on_racket_active_timeout():
	action_active = false
func _on_racket_cooldown_timeout():
	action_ready = true
func _on_racket_hold_timeout():
	action_hold = false
func _on_action_pressed_timeout():
	last_movement_action_pressed = null

func _process(_delta):
	if UI.get_node('Menu').visible or UI.get_node('GameControls').visible: return
	
	#direction
	var input_dir = Input.get_vector("left", "right", "up", "down")
	direction = (get_parent().transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	#aim direction
	var window_size = get_viewport().get_visible_rect().size
	var mouse_pos = get_viewport().get_mouse_position()
	var aim_x = clamp(mouse_pos.x / window_size.x, 0, 1) - 0.5
	var aim_y = 0.35 + abs(clamp(mouse_pos.y / window_size.y, 0, 1) - 1) * 0.65
	aim_direction = Vector2(aim_x, aim_y)
	set_aim_x.rpc(aim_x)
	
	# racket hold
	if action_hold:
		var hold_mult = ((PlayerVariables.ACTION_HOLD_TIME -
				$RacketHold.time_left) /
				PlayerVariables.ACTION_HOLD_TIME)
		#set_action_hold_progress.rpc(hold_mult)
		#action_hold_progress = hold_mult
		set_throw_power.rpc(PlayerVariables.BASE_POWER +
				(PlayerVariables.MAX_POWER -
				PlayerVariables.BASE_POWER) * hold_mult)
