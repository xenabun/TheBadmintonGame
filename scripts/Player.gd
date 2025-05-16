extends CharacterBody3D

@export var player_id : int = 0
@export var player_num : int = 1
@export var opponent_id : int = 0
@export var match_id : int = 0
@export var username : String = ""
@export var stamina_bar : Node
@export var throw_power : float = PlayerVariables.MAX_POWER
@export var aim_x : float = 0
@export var can_play : bool = true
@export var can_throw : bool = false

@export var direction : Vector3 = Vector3.ZERO
@export var sprinting : bool = false
@export var stamina : float = PlayerVariables.MAX_STAMINA:
	set(value):
		stamina = value
		stamina_bar.value = value
@export var exhausted : bool = false:
	set(value):
		exhausted = value
		stamina_bar.get("theme_override_styles/fill").bg_color = Color.html(
				PlayerVariables.STAMINA_BAR_COLOR_LOCKED if value else
				PlayerVariables.STAMINA_BAR_COLOR_NORMAL)
@export var aim_direction : Vector2 = Vector2.ZERO

@onready var Level = get_tree().get_root().get_node('Scene/Level')
@onready var UI = get_tree().get_root().get_node('Scene/UI')
@onready var Network = get_tree().get_root().get_node('Scene/Network')

@onready var animation_tree = get_node('AnimationTree')
@onready var player_model = get_node('playermodel')
@onready var player_angle_target = get_node('plrangletarget')
@onready var racket_area = get_node('RacketArea')
@onready var username_billboard = get_node('Username')
@onready var aim_arrow = get_node('AimArrow')
@onready var aim_arrow_sprite = get_node('AimArrow/Sprite')
@onready var racket_active_timer = get_node('RacketActive')
@onready var racket_cooldown_timer = get_node('RacketCooldown')
@onready var racket_hold_timer = get_node('RacketHold')
@onready var action_pressed_timer = get_node('ActionPressed')

var action_ready = true
var action_hold = false:
	set(value):
		action_hold = value
		if value == false:
			action_ready = false
			racket_active_timer.start()
			racket_cooldown_timer.start()
			racket_swing.rpc()
			get_node('AimArrow').hide()
var action_active = false:
	set(value):
		action_active = value
		racket_area_activate.rpc(value)
var movement_actions = [false, false, false, false] # up right down left
var last_movement_action_pressed = null
var shift_hold = false

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var speed = PlayerVariables.BASE_SPEED
var prev_direction = Vector3.ZERO
var camera

@rpc('any_peer', 'call_local')
func set_can_throw(value):
	can_throw = value

@rpc('any_peer', 'call_local')
func reset_position():
	var spawn_point = Level.get_node('World/Player' + str(player_num)
			+ 'Spawn' + Game.get_throw_side(match_id, player_num, can_throw))
	position = spawn_point.position
	rotation = spawn_point.rotation
	update_camera_transform(1)

func _ready():
	player_id = get_multiplayer_authority()
	Game.print_debug_msg('player _ready() call: uid: ' + str(multiplayer.get_unique_id()) + ' plr_id: ' + str(player_id))
	Game.print_debug_msg('multiplayer authority: ' + str(get_multiplayer_authority()))
	get_node('RacketArea/CSGBox3D').hide()
	aim_arrow.hide()
	racket_hold_timer.wait_time = PlayerVariables.ACTION_HOLD_TIME

	set_physics_process(multiplayer.get_unique_id() == player_id)

	var player_data = Network.Players[player_id]
	var current_authority = multiplayer.get_unique_id()
	if Network.Players.has(current_authority):
		var current_authority_player_data = Network.Players[current_authority]
		if (player_data and player_data.has('match_id') and current_authority_player_data
				and current_authority_player_data.has('match_id')):
			visible = player_data.match_id == current_authority_player_data.match_id

	if multiplayer.get_unique_id() != player_id: return

	if player_data:
		player_num = player_data.num
		opponent_id = player_data.opponent_id
		can_throw = player_num == 1
		match_id = player_data.match_id
		username = player_data.username
		username_billboard.text = player_data.username
		Game.print_debug_msg('getting player data: username: ' + str(player_data.username))
	else:
		Game.print_debug_msg('getting player data: not found')
		return

	camera = Level.get_node('World/PlayerCamera')
	var menu_camera = UI.menu_camera_pivot.get_node('MenuCamera')
	camera.make_current()
	camera.global_position = menu_camera.global_position
	camera.global_rotation = menu_camera.global_rotation
	update_camera_transform(1)
	UI.state.showing_game_ui.set_state(true, {stamina = true, match_switch = false})
	UI.get_node('GameControls').show()
	if Game.current_game_type == Game.game_type.MULTIPLAYER:
		can_play = false
	stamina_bar = UI.get_node('GameUI/StaminaBarControl/StaminaBar')
	stamina_bar.max_value = PlayerVariables.MAX_STAMINA
	stamina_bar.value = stamina
	stamina_bar.show()
	animation_tree.animation_finished.connect(_on_animation_finished)
	Input.set_mouse_mode(Input.MouseMode.MOUSE_MODE_VISIBLE)

@rpc('any_peer')
func reset_authority():
	set_multiplayer_authority(1)

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())
	

@rpc('any_peer', 'call_local')
func racket_area_activate(value):
	get_node('RacketArea').monitorable = value
	if Game.debug:
		get_node('RacketArea/CSGBox3D').visible = value

@rpc("any_peer", "call_local")
func throw_ready():
	animation_tree['parameters/Throw/request'] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
@rpc("any_peer", "call_local")
func racket_hold():
	animation_tree['parameters/RacketHold/request'] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
@rpc('any_peer', 'call_local')
func racket_hold_idle():
	animation_tree['parameters/RacketHoldIdle/request'] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
@rpc("any_peer", "call_local")
func racket_swing():
	animation_tree['parameters/RacketHold/request'] = AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT
	animation_tree['parameters/RacketHoldIdle/request'] = AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT
	animation_tree['parameters/RacketSwing/request'] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
func _on_animation_finished(anim_name):
	if anim_name == 'playeranims/RacketHold':
		racket_hold_idle.rpc()

func is_game_paused():
	return UI.get_node('Menu').visible or UI.get_node('GameControls').visible

func _on_racket_active_timeout():
	action_active = false
func _on_racket_cooldown_timeout():
	action_ready = true
func _on_racket_hold_timeout():
	action_hold = false
func _on_action_pressed_timeout():
	last_movement_action_pressed = null

func get_camera_transform_info():
	var side = Game.get_player_side(player_num)
	var cam_pos_x = position.x
	var cam_pos_z = position.z + (20 * side)
	var player_pos_x_frac = position.x / PlayerVariables.X_LIMIT * side
	var player_pos_z_frac = position.z / PlayerVariables.Z_LIMIT * side
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
		'cam_rot_y' = cam_rot_y + PI * (player_num - 1),
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

func _input(event):
	if get_multiplayer_authority() != multiplayer.get_unique_id(): return
	
	if event.is_action_pressed('ui_cancel'):
		if UI.get_node('GameControls').visible:
			UI.get_node('GameControls').visible = false
		else:
			var current_state = UI.state.in_game_menu.get_state()
			var new_state = not current_state
			UI.state.in_game_menu.set_state(new_state)
	
	if not Game.is_match_in_progress(match_id) or is_game_paused(): return
	
	if can_play:
		if event.is_action_pressed('action'):
			if can_throw and Game.is_match_in_progress(match_id):
				var ball = Game.get_ball_by_match_id(match_id)
				# var opponent_id = Game.get_opponent_id(player_id)
				var opponent_player_object = Level.get_node('Players/' + str(opponent_id))
				if opponent_player_object.can_play and ball != null and ball.ball_ready:
					var pos = get_node('Ball').global_position
					var new_direction = VectorMath.look_vector(get_node('RacketArea')).z
					var _aim_x = sin((aim_direction.x * 2 * PI) / 2)
					var _aim_y = aim_direction.y
					var new_velocity_x = _aim_x * 30 * -new_direction
					can_throw = false
					ball.throw_ball.rpc(opponent_id,
							# Game.get_opponent_id(multiplayer.get_unique_id()),
							name, pos, new_direction, new_velocity_x, _aim_y)
					get_node('AimArrow').hide()
					throw_ready.rpc()
			else:
				if action_ready and not action_active:
					action_hold = true
					racket_hold_timer.start()
					action_active = true
					racket_hold.rpc()
		if event.is_action_released('action') and action_hold:
			racket_hold_timer.stop()
			action_hold = false
	
	if event.is_action_pressed('leaderboard'):
		UI.state.showing_leaderboard.set_state(true, false)
	if event.is_action_released('leaderboard'):
		UI.state.showing_leaderboard.set_state(false, false)

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
				action_pressed_timer.time_left > 0):
			sprinting = true
		if not sprinting and last_movement_action_pressed != current_action:
			action_pressed_timer.start()
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

func _physics_process(delta):
	if not Game.is_match_in_progress(match_id):
		if animation_tree.active:
			animation_tree.active = false
		return
	if not animation_tree.active:
		animation_tree.active = true
	
	# gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
		animation_tree['parameters/WalkScale/scale'] = move_toward(
				animation_tree['parameters/WalkScale/scale'], 0, 0.02)
	else:
		animation_tree['parameters/WalkScale/scale'] = move_toward(
				animation_tree['parameters/WalkScale/scale'], 1, 0.1)
	
	# jump
	if (
		Input.is_action_just_pressed("ui_accept")
		and not UI.get_node('Menu').visible
		and not UI.get_node('GameControls').visible
		and is_on_floor()
	):
		velocity.y = PlayerVariables.JUMP_VELOCITY
	
	#direction
	var input_dir = Input.get_vector("left", "right", "up", "down")
	direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	#aim direction
	var window_size = get_viewport().get_visible_rect().size
	var mouse_pos = get_viewport().get_mouse_position()
	var ball = Game.get_ball_by_match_id(match_id)
	var _aim_x = (clamp(mouse_pos.x / window_size.x, 0, 1) - 0.5) * 2
	
	#aim correction for throwing
	if ball and ball.ball_ready:
		var throw_side = Game.get_throw_side(match_id, player_num, can_throw)
		var aim_side = -0.125 if throw_side == 'Even' else 0.125
		_aim_x = _aim_x * 0.125 + aim_side
	
	var _aim_y = 0.35 + abs(clamp(mouse_pos.y / window_size.y, 0, 1) - 1) * 0.65
	aim_direction = Vector2(_aim_x, _aim_y)
	aim_x = _aim_x
	
	# racket hold
	if action_hold:
		var hold_mult = ((PlayerVariables.ACTION_HOLD_TIME -
				racket_hold_timer.time_left) /
				PlayerVariables.ACTION_HOLD_TIME)
		throw_power = (PlayerVariables.BASE_POWER +
				(PlayerVariables.MAX_POWER -
				PlayerVariables.BASE_POWER) * hold_mult)
	
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
		if not action_hold:
			player_angle_target.look_at(player_angle_target.global_position + direction)
			var currot = Quaternion(player_model.transform.basis.orthonormalized())
			var tarrot = Quaternion(player_angle_target.transform.basis.orthonormalized())
			var newrot = currot.slerp(tarrot, 0.2)
			player_model.transform.basis = Basis(newrot).scaled(player_model.scale)
	animation_tree['parameters/WalkSpeed/blend_amount'] = move_toward(
		animation_tree['parameters/WalkSpeed/blend_amount'],
		blend_amount,
		0.1
	)
	if action_hold:
		player_angle_target.look_at(player_angle_target.global_position + VectorMath.look_vector(racket_area))
		var currot = Quaternion(player_model.transform.basis.orthonormalized())
		var tarrot = Quaternion(player_angle_target.transform.basis.orthonormalized())
		var newrot = currot.slerp(tarrot, 0.3)
		newrot.y += -aim_direction.x / 4.0
		newrot.w += -aim_direction.x / 4.0
		player_model.transform.basis = Basis(newrot).scaled(player_model.scale)
	
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
	var vel = direction.normalized() * speed
	velocity = Vector3(vel.x, velocity.y, vel.z)
	
	# position
	move_and_slide()
	var side = Game.get_player_side(player_num)
	if ball and ball.ball_ready:
		var throw_side = Game.get_throw_side(match_id, player_num, can_throw)
		var throw_size_x = 1 if throw_side == 'Even' else -1
		var z_clamp = [PlayerVariables.Z_THROW_LIMIT * side, PlayerVariables.Z_LIMIT * side]
		var x_clamp = [0, PlayerVariables.X_THROW_LIMIT * side * throw_size_x]
		position.x = clamp(position.x, min(x_clamp[0], x_clamp[1]), max(x_clamp[0], x_clamp[1]))
		position.z = clamp(position.z, min(z_clamp[0], z_clamp[1]), max(z_clamp[0], z_clamp[1]))
	else:
		var z_clamp = [2 * side, PlayerVariables.Z_LIMIT * side]
		position.x = clamp(position.x, -PlayerVariables.X_LIMIT, PlayerVariables.X_LIMIT)
		position.z = clamp(position.z, min(z_clamp[0], z_clamp[1]), max(z_clamp[0], z_clamp[1]))
	
	# aim arrow
	if can_play and can_throw or action_hold:
		# var opponent_id = Game.get_opponent_id(player_id)
		var opponent_player_object = Level.get_node('Players/' + str(opponent_id))
		if opponent_player_object.can_play:
			aim_arrow.global_position = global_position * Vector3(1, 0, 1) + Vector3(0, 1, 0)
			if not aim_arrow.visible:
				aim_arrow_sprite.scale.x = 0
				aim_arrow_sprite.scale.y = 0
				aim_arrow.position.z = 0
				aim_arrow.show()
	else: # if not can_play and aim_arrow.visible:
		if aim_arrow.visible:
			aim_arrow.hide()
	
	if Game.window_focus and not is_game_paused():
		# camera
		update_camera_transform(0.2)
		
		# aim arrow
		if action_hold:
			var hold_mult = ((PlayerVariables.ACTION_HOLD_TIME -
				racket_hold_timer.time_left) /
				PlayerVariables.ACTION_HOLD_TIME)
			aim_arrow_sprite.scale.x = hold_mult * 20
			aim_arrow_sprite.scale.y = hold_mult * 5
			aim_arrow_sprite.position.z = -hold_mult * 10
		else:
			aim_arrow_sprite.scale.x = aim_direction.y * 20
			aim_arrow_sprite.scale.y = aim_direction.y * 5
			aim_arrow_sprite.position.z = -aim_direction.y * 10
		aim_arrow.rotation.y = -sin((aim_direction.x * PI) / 2)
