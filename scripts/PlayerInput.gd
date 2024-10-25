extends MultiplayerSynchronizer

@export var direction := Vector3()
@export var player : Node

func _ready():
	set_process(get_multiplayer_authority() == multiplayer.get_unique_id())
	player = get_parent()

var action_ready = true
var action_hold = false:
	set(value):
		action_hold = value
		if value == false:
			action_ready = false
			$RacketActive.start()
			$RacketCooldown.start()
			$AnimationTree['parameters/RacketHold/request'] = AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT
			$AnimationTree['parameters/RacketSwing/request'] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
var action_active = false:
	set(value):
		action_active = value
		$RacketArea.monitorable = value
var movement_actions = [false, false, false, false] # up right down left

func _input(event):
	if get_multiplayer_authority() != multiplayer.get_unique_id():
		return
	#if event.is_action_pressed('ui_cancel'):
		#Game.game_in_progress = not Game.game_in_progress
		#menu.visible = not Game.game_in_progress
	
	if not Game.game_in_progress: return
	
	if event.is_action_pressed('action'):
		if player.ball_ready and Game.game_in_progress:
			#ball.position = $Ball.global_position
			#ball.set('direction', VectorMath.look_vector($RacketArea).z)
			#ball.set('power', PlayerVariables.MAX_POWER)
			#ball.set('launch_y', $Ball.global_position.y)
			#ball.set('launch_z', $Ball.global_position.z)
			#ball.set('last_interact', name)
			#set('ball_ready', false)
			#$AnimationTree['parameters/Throw/request'] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
			player
		else:
			if action_ready and not action_active:
				action_hold = true
				$RacketHold.start()
				action_active = true
				$AnimationTree['parameters/RacketHold/request'] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
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
	var input_dir = Input.get_vector("left", "right", "up", "down")
	direction = (get_parent().transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
