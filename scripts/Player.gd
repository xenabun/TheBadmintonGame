extends CharacterBody3D

@export var player_id = 1 :
	set(id):
		player_id = id
		$PlayerInput.set_multiplayer_authority(id)
@export var username : String = ""
@onready var input = $PlayerInput
var player_data_set = false

@rpc('any_peer', 'call_local')
func _set_player_data(_player_id):
	var player_data = GameManager.Players[_player_id]
	username = player_data.username
	#$Control/Username.text = username

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var speed = PlayerVariables.BASE_SPEED
var throw_power = PlayerVariables.MAX_POWER
var prev_direction = Vector3.ZERO
var stamina = PlayerVariables.MAX_STAMINA:
	set(value):
		stamina = value
		stamina_bar.value = value
var exhausted = false:
	set(value):
		exhausted = value
		stamina_bar.get("theme_override_styles/fill").bg_color = Color.html(
				PlayerVariables.STAMINA_BAR_COLOR_LOCKED if value else
				PlayerVariables.STAMINA_BAR_COLOR_NORMAL)
var sprinting = false
var movement_actions = [false, false, false, false] # up right down left
var last_movement_action_pressed = null

@onready var ball = get_tree().get_root().get_node('Scene/Level/World/Ball')
@onready var camera = get_tree().get_root().get_node('Scene/Level/World/PlayerCamera')
@onready var UI = get_tree().get_first_node_in_group('UI_root')
@onready var GameUI = UI.get_node('GameUI')
@onready var stamina_bar = GameUI.get_node('StaminaBarControl/StaminaBar')
#@onready var menu = get_parent().get_node('Menu')
func _ready():
	camera.set_current(true)
	GameUI.show()
	$RacketHold.wait_time = PlayerVariables.ACTION_HOLD_TIME
	stamina_bar.max_value = PlayerVariables.MAX_STAMINA
	stamina_bar.value = stamina

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
var ball_ready = true:
	set(value):
		ball_ready = value
		$Ball.visible = value
		if value == true and Game.game_in_progress:
			position = Vector3(0, 1.172, 15)
			#bot.position = Vector3(0, 1.172, -15)
			update_camera_transform(1)
func get_camera_transform_info():
	var cam_pos_x = position.x
	var cam_pos_z = position.z + 20
	var player_pos_x_frac = position.x / PlayerVariables.X_LIMIT
	var player_pos_z_frac = position.z / PlayerVariables.Z_LIMIT
	var screen_width = get_viewport().get_visible_rect().size.x
	var mouse_x = get_viewport().get_mouse_position().x
	var mouse_on_screen_frac = -((mouse_x / screen_width) - 0.5) * 2
	var cam_rot_y = (
		player_pos_x_frac * (PI / 50) +
		(1.5 - player_pos_z_frac) *
		player_pos_x_frac * (PI / 20) +
		mouse_on_screen_frac * (PI / 60)
	)
	return {
		'cam_pos_x' = cam_pos_x,
		'cam_pos_z' = cam_pos_z,
		'cam_rot_y' = cam_rot_y,
	}
func update_camera_transform(t):
	var cam_info = get_camera_transform_info()
	camera.position.x = move_toward(
			camera.position.x,
			cam_info.cam_pos_x,
			abs(cam_info.cam_pos_x - camera.position.x) * t
	)
	camera.position.z = move_toward(
			camera.position.z,
			cam_info.cam_pos_z,
			abs(cam_info.cam_pos_z - camera.position.z) * t
	)
	camera.rotation.y = move_toward(
			camera.rotation.y,
			cam_info.cam_rot_y,
			abs(cam_info.cam_rot_y - camera.rotation.y) * t
	)
func _on_racket_active_timeout():
	action_active = false
func _on_racket_cooldown_timeout():
	action_ready = true
func _on_racket_hold_timeout():
	action_hold = false
func _on_action_pressed_timeout():
	last_movement_action_pressed = null

func _input(event):
	#if event.is_action_pressed('ui_cancel'):
		#Game.game_in_progress = not Game.game_in_progress
		#menu.visible = not Game.game_in_progress
	
	if not Game.game_in_progress: return
	
	if event.is_action_pressed('action'):
		if ball_ready and Game.game_in_progress:
			ball.position = $Ball.global_position
			ball.set('direction', VectorMath.look_vector($RacketArea).z)
			ball.set('power', PlayerVariables.MAX_POWER)
			ball.set('launch_y', $Ball.global_position.y)
			ball.set('launch_z', $Ball.global_position.z)
			ball.set('last_interact', name)
			set('ball_ready', false)
			$AnimationTree['parameters/Throw/request'] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
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

func _physics_process(delta):
	if $PlayerInput.get_multiplayer_authority() != multiplayer.get_unique_id():
		return
	if not player_data_set and GameManager.Players.has(player_id):
		player_data_set = true
		_set_player_data.rpc(player_id)
	if not Game.game_in_progress:
		$AnimationTree.active = false
		return
	$AnimationTree.active = true
	
	# racket hold
	if action_hold:
		var hold_mult = ((PlayerVariables.ACTION_HOLD_TIME -
				$RacketHold.time_left) /
				PlayerVariables.ACTION_HOLD_TIME)
		throw_power = (PlayerVariables.BASE_POWER +
				(PlayerVariables.MAX_POWER -
				PlayerVariables.BASE_POWER) * hold_mult)
	
	# gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
		$AnimationTree['parameters/WalkScale/scale'] = move_toward(
				$AnimationTree['parameters/WalkScale/scale'], 0, 0.02)
	else:
		$AnimationTree['parameters/WalkScale/scale'] = move_toward(
				$AnimationTree['parameters/WalkScale/scale'], 1, 0.1)
	
	# jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = PlayerVariables.JUMP_VELOCITY
	
	# direction
	#var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = input.direction #(transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# speed
	if (
		prev_direction.length() > 0 and
		direction.length() > 0 and
		direction.dot(prev_direction) <= 0
	):
		speed = PlayerVariables.BASE_SPEED
	if direction.length() > 0:
		var max_speed = PlayerVariables.MAX_SPEED
		var accel = PlayerVariables.ACCELERATION
		if sprinting and not exhausted and stamina > 0:
			max_speed *= PlayerVariables.RUN_SPEED_MULT
			accel *= PlayerVariables.RUN_SPEED_MULT
		speed = move_toward(speed, max_speed, accel)
	else:
		speed = PlayerVariables.BASE_SPEED
	prev_direction = direction
	
	# animation
	var blend_amount = 0
	if direction.length() > 0:
		if sprinting and not exhausted and stamina > 0:
			blend_amount = 1
		else:
			blend_amount = 0.5
	$AnimationTree['parameters/WalkSpeed/blend_amount'] = move_toward(
		$AnimationTree['parameters/WalkSpeed/blend_amount'],
		blend_amount,
		0.1
	)
	if direction.length() > 0:
		$plrangletarget.look_at($plrangletarget.global_position + direction)
		var currot = Quaternion($playermodel.transform.basis.orthonormalized())
		var tarrot = Quaternion($plrangletarget.transform.basis.orthonormalized())
		var newrot = currot.slerp(tarrot, 0.2)
		$playermodel.transform.basis = Basis(newrot).scaled($playermodel.scale)
	
	# stamina
	if sprinting and not exhausted and direction.length() > 0:
		stamina = max(stamina - PlayerVariables.STAMINA_DELPETION, 0)
		if stamina <= 0:
			sprinting = false
			exhausted = true
	else:
		stamina = min(stamina + PlayerVariables.STAMINA_REGEN,
				PlayerVariables.MAX_STAMINA)
		if stamina >= PlayerVariables.MAX_STAMINA:
			exhausted = false
	
	# velocity
	var vel = Vector3(sign(direction.x), 0, sign(direction.z)).normalized() * speed
	velocity = Vector3(vel.x, velocity.y, vel.z)
	
	# position
	move_and_slide()
	position.x = clamp(position.x, -PlayerVariables.X_LIMIT, PlayerVariables.X_LIMIT)
	position.z = clamp(position.z, 2, PlayerVariables.Z_LIMIT)
	
	# camera
	update_camera_transform(0.2)
	
