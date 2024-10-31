extends MultiplayerSynchronizer

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
@onready var UI = get_tree().get_first_node_in_group('UI_root')

var action_ready = true
var action_hold = false:
	set(value):
		action_hold = value
		if value == false:
			action_ready = false
			$RacketActive.start()
			$RacketCooldown.start()
			#player.actions.racket_swing = true
			racket_swing.rpc()
			#$AnimationTree['parameters/RacketHold/request'] = AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT
			#$AnimationTree['parameters/RacketSwing/request'] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
var action_active = false:
	set(value):
		action_active = value
		racket_area_activate.rpc(value)
		#$RacketArea.monitorable = value
var movement_actions = [false, false, false, false] # up right down left
var last_movement_action_pressed = null

@rpc('any_peer', 'call_local')
func racket_area_activate(value):
	#$RacketArea.monitorable = value
	player.get_node('RacketArea').monitorable = value
	#player.get_node('RacketArea/CSGBox3D').visible = value

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

func _ready():
	var authority = get_multiplayer_authority() == multiplayer.get_unique_id()
	set_process(authority)
	#set_block_signals(authority)
	player = get_parent()
	$RacketHold.wait_time = PlayerVariables.ACTION_HOLD_TIME

func _input(event):
	if get_multiplayer_authority() != multiplayer.get_unique_id(): return
	
	if event.is_action_pressed('ui_cancel'):
		#Game.game_in_progress = not Game.game_in_progress
		#menu.visible = not Game.game_in_progress
		var menu = UI.get_node('Menu')
		menu.visible = not menu.visible
	
	if UI.get_node('Menu').visible: return
	if not Game.game_in_progress: return
	
	if event.is_action_pressed('action'):
		if Game.ball_ready and Game.game_in_progress:
			##ball.position = $Ball.global_position
			##ball.set('direction', VectorMath.look_vector($RacketArea).z)
			##ball.set('power', PlayerVariables.MAX_POWER)
			##ball.set('launch_y', $Ball.global_position.y)
			##ball.set('launch_z', $Ball.global_position.z)
			##ball.set('last_interact', name)
			##set('ball_ready', false)
			#Game.ball_ready = false
			
			var dir = VectorMath.look_vector(player.get_node('RacketArea')).z
			var pos = player.get_node('Ball').global_position
			Game.throw_ball.rpc(Game.get_opponent_peer_id(multiplayer.get_unique_id()), pos, dir)
			player.get_node('Ball').visible = false
			
			#$AnimationTree['parameters/Throw/request'] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
			#player.actions.throw_ready = true
			throw_ready.rpc()
			pass
		else:
			if action_ready and not action_active:
				action_hold = true
				$RacketHold.start()
				action_active = true
				#$AnimationTree['parameters/RacketHold/request'] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
				#player.actions.racket_hold = true
				racket_hold.rpc()
	if event.is_action_released('action') and action_hold:
		$RacketHold.stop()
		action_hold = false
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
				movement_actions[3] == false):
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
	if UI.get_node('Menu').visible: return
	
	#direction
	var input_dir = Input.get_vector("left", "right", "up", "down")
	direction = (get_parent().transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# racket hold
	if action_hold:
		var hold_mult = ((PlayerVariables.ACTION_HOLD_TIME -
				$RacketHold.time_left) /
				PlayerVariables.ACTION_HOLD_TIME)
		#player.throw_power = (PlayerVariables.BASE_POWER +
				#(PlayerVariables.MAX_POWER -
				#PlayerVariables.BASE_POWER) * hold_mult)
		set_throw_power.rpc(PlayerVariables.BASE_POWER +
				(PlayerVariables.MAX_POWER -
				PlayerVariables.BASE_POWER) * hold_mult)
	
	## stamina
	#if sprinting and not exhausted and direction.length() > 0:
		#stamina = max(stamina - PlayerVariables.STAMINA_DELPETION, 0)
		#if stamina <= 0:
			#sprinting = false
			#exhausted = true
	#else:
		#stamina = min(stamina + PlayerVariables.STAMINA_REGEN,
				#PlayerVariables.MAX_STAMINA)
		#if stamina >= PlayerVariables.MAX_STAMINA:
			#exhausted = false
