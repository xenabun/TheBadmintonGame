extends CharacterBody3D

@export var player_id : int = 0
@export var player_num : int = 1
@export var match_id : int = 0
@export var username : String = ""
@export var stamina_bar : Node
@export var throw_power : float = PlayerVariables.MAX_POWER
@export var aim_x : float = 0
## TODO: wait for guide to be hidden and then let players play
@export var can_play : bool = true
@export var can_throw : bool = false

@onready var Level = get_tree().get_root().get_node('Scene/Level')
@onready var UI = get_tree().get_root().get_node('Scene/UI')
@onready var Network = get_tree().get_root().get_node('Scene/Network')

@onready var input = get_node('PlayerInput')
@onready var racket_hold_timer = get_node('PlayerInput/RacketHold')
@onready var animation_tree = get_node('AnimationTree')
@onready var player_model = get_node('playermodel')
@onready var player_angle_target = get_node('plrangletarget')
@onready var racket_area = get_node('RacketArea')
@onready var username_billboard = get_node('Username')
@onready var aim_arrow = get_node('AimArrow')
@onready var aim_arrow_sprite = get_node('AimArrow/Sprite')

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var speed = PlayerVariables.BASE_SPEED
var prev_direction = Vector3.ZERO
var camera
# var ball

# @rpc('any_peer')
# func reset_ball():
# 	ball = null

@rpc('any_peer')
func set_can_throw(value):
	can_throw = value

func get_player_side():
	return 1 if player_num == 1 else -1

func get_throw_side():
	var player_index = player_num - 1
	if not can_throw:
		player_index = Game.get_opponent_index(player_index)
	var player_round_score = Game.get_player_round_score(match_id, player_index)
	var side = 'Even' if player_round_score % 2 == 0 else 'Odd'
	return side

@rpc('any_peer')
func reset_position():
	var spawn_point = Level.get_node('World/Player' + str(player_num) + 'Spawn' + get_throw_side())
	position = spawn_point.position
	rotation = spawn_point.rotation
	update_camera_transform(1)

func _ready():
	player_id = get_multiplayer_authority()
	Game.print_debug_msg('player _ready() call: uid: ' + str(multiplayer.get_unique_id()) + ' plr_id: ' + str(player_id))
	Game.print_debug_msg('multiplayer authority: ' + str(get_multiplayer_authority()))
	aim_arrow.hide()

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
		can_throw = player_num == 1
		match_id = player_data.match_id
		username = player_data.username
		username_billboard.text = player_data.username
		# ball = Game.get_ball_by_match_id(match_id)
		Game.print_debug_msg('getting player data: username: ' + str(player_data.username))
	else:
		Game.print_debug_msg('getting player data: not found')
		return

	# reset_position.connect(_reset_position)
	camera = Level.get_node('World/PlayerCamera')
	var menu_camera = UI.menu_camera_pivot.get_node('MenuCamera')
	var GameUI = UI.get_node('GameUI')
	var GameControls = UI.get_node('GameControls')
	camera.make_current()
	camera.global_position = menu_camera.global_position
	camera.global_rotation = menu_camera.global_rotation
	update_camera_transform(0.2)
	GameUI.show()
	GameControls.show()
	UI.leaderboard_init()
	stamina_bar = GameUI.get_node('StaminaBarControl/StaminaBar')
	stamina_bar.max_value = PlayerVariables.MAX_STAMINA
	stamina_bar.value = input.stamina
	stamina_bar.show()
	Input.set_mouse_mode(Input.MouseMode.MOUSE_MODE_VISIBLE)

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())

func get_camera_transform_info():
	var side = get_player_side()
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

func _physics_process(delta):
	# print('physics step player_id: ', player_id, ' by ', multiplayer.get_unique_id())
	# if not Game.game_in_progress:
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
	
	# direction
	var direction = input.direction
	
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
		if input.sprinting and not input.exhausted and input.stamina > 0:
			max_speed *= PlayerVariables.RUN_SPEED_MULT
			accel *= PlayerVariables.RUN_SPEED_MULT
		speed = move_toward(speed, max_speed, accel)
	else:
		speed = PlayerVariables.BASE_SPEED
	prev_direction = direction
	
	# animation
	var blend_amount = 0
	if direction.length() > 0:
		if input.sprinting and not input.exhausted and input.stamina > 0:
			blend_amount = 1
		else:
			blend_amount = 0.5
		if not input.action_hold:
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
	if input.action_hold:
		player_angle_target.look_at(player_angle_target.global_position + VectorMath.look_vector(racket_area))
		var currot = Quaternion(player_model.transform.basis.orthonormalized())
		var tarrot = Quaternion(player_angle_target.transform.basis.orthonormalized())
		var newrot = currot.slerp(tarrot, 0.3)
		newrot.y += -input.aim_direction.x / 4.0
		newrot.w += -input.aim_direction.x / 4.0
		player_model.transform.basis = Basis(newrot).scaled(player_model.scale)
	
	# stamina
	if input.sprinting and not input.exhausted and direction.length() > 0:
		input.stamina = max(input.stamina - PlayerVariables.STAMINA_DELPETION, 0)
		if input.stamina <= 0:
			input.sprinting = false
			input.exhausted = true
	else:
		input.stamina = min(input.stamina + PlayerVariables.STAMINA_REGEN,
				PlayerVariables.MAX_STAMINA)
		if input.stamina >= PlayerVariables.MAX_STAMINA:
			input.exhausted = false
	
	# velocity
	var vel = direction.normalized() * speed
	velocity = Vector3(vel.x, velocity.y, vel.z)
	
	# position
	move_and_slide()
	var side = get_player_side()
	# ERROR ball is null
	if Game.get_ball_by_match_id(match_id).ball_ready:
		var throw_side = get_throw_side()
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
	if can_throw or input.action_hold:
		aim_arrow.global_position = global_position * Vector3(1, 0, 1) + Vector3(0, 1, 0)
		if not aim_arrow.visible:
			aim_arrow_sprite.scale.x = 0
			aim_arrow_sprite.scale.y = 0
			aim_arrow.position.z = 0
			aim_arrow.show()
	
	if Game.window_focus and not input.is_game_paused():
		# camera
		update_camera_transform(0.2)
		
		# aim arrow
		var aim_dir = input.aim_direction
		if input.action_hold:
			var hold_mult = ((PlayerVariables.ACTION_HOLD_TIME -
				racket_hold_timer.time_left) /
				PlayerVariables.ACTION_HOLD_TIME)
			aim_arrow_sprite.scale.x = hold_mult * 20
			aim_arrow_sprite.scale.y = hold_mult * 5
			aim_arrow_sprite.position.z = -hold_mult * 10
		else:
			aim_arrow_sprite.scale.x = aim_dir.y * 20
			aim_arrow_sprite.scale.y = aim_dir.y * 5
			aim_arrow_sprite.position.z = -aim_dir.y * 10
		aim_arrow.rotation.y = -sin((aim_dir.x * PI) / 2)
