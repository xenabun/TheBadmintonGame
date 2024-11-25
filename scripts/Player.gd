extends CharacterBody3D

@export var player_id = 1 :
	set(id):
		player_id = id
		$PlayerInput.set_multiplayer_authority(id)
@export var username : String = ""
@onready var input = $PlayerInput
func get_player_side():
	return 1 if player_id == 1 else -1
func get_player_num():
	return 1 if player_id == 1 else 2

@export var throw_power = PlayerVariables.MAX_POWER
#@export var action_hold_progress = 1
@export var aim_x = 0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var speed = PlayerVariables.BASE_SPEED
var prev_direction = Vector3.ZERO

@onready var Level = get_tree().get_first_node_in_group('Level_root')
@onready var camera = Level.get_node('World/PlayerCamera')
@onready var UI = get_tree().get_first_node_in_group('UI_root')
@onready var GameUI = UI.get_node('GameUI')
@export var stamina_bar : Node

signal reset_position
func _reset_position():
	var num = get_player_num()
	var spawn_point = Level.get_node('World/Player' + str(num) + 'Spawn')
	position = spawn_point.position
	rotation = spawn_point.rotation
	update_camera_transform(1)

func _ready():
	GameManager.print_debug_msg('player _ready() call: uid: ' + str(multiplayer.get_unique_id()) + ' plr_id: ' + str(player_id))
	set_physics_process(multiplayer.get_unique_id() == player_id)
	$AimArrow.hide()
	if multiplayer.get_unique_id() != player_id: return
	
	var player_data = GameManager.Players.get(player_id)
	if player_data:
		username = player_data.username
		$Username.text = player_data.username
		GameManager.print_debug_msg('getting player data: username: ' + str(player_data.username))
	else:
		GameManager.print_debug_msg('getting player data: not found')
	reset_position.connect(_reset_position)
	camera.make_current()
	var menu_camera = UI.menu_camera_pivot.get_node('MenuCamera')
	camera.global_position = menu_camera.global_position
	camera.global_rotation = menu_camera.global_rotation
	update_camera_transform(0.2)
	GameUI.show()
	UI.get_node('GameControls').show()
	stamina_bar = GameUI.get_node('StaminaBarControl/StaminaBar')
	stamina_bar.max_value = PlayerVariables.MAX_STAMINA
	stamina_bar.value = input.stamina

func get_camera_transform_info():
	var side = get_player_side()
	var num = get_player_num()
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
		'cam_rot_y' = cam_rot_y + PI * (num - 1),
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
	if not Game.game_in_progress:
		if $AnimationTree.active:
			$AnimationTree.active = false
		return
	if not $AnimationTree.active:
		$AnimationTree.active = true
	
	# gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
		$AnimationTree['parameters/WalkScale/scale'] = move_toward(
				$AnimationTree['parameters/WalkScale/scale'], 0, 0.02)
	else:
		$AnimationTree['parameters/WalkScale/scale'] = move_toward(
				$AnimationTree['parameters/WalkScale/scale'], 1, 0.1)
	
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
			$plrangletarget.look_at($plrangletarget.global_position + direction)
			var currot = Quaternion($playermodel.transform.basis.orthonormalized())
			var tarrot = Quaternion($plrangletarget.transform.basis.orthonormalized())
			var newrot = currot.slerp(tarrot, 0.2)
			$playermodel.transform.basis = Basis(newrot).scaled($playermodel.scale)
	$AnimationTree['parameters/WalkSpeed/blend_amount'] = move_toward(
		$AnimationTree['parameters/WalkSpeed/blend_amount'],
		blend_amount,
		0.1
	)
	if input.action_hold:
		$plrangletarget.look_at($plrangletarget.global_position + VectorMath.look_vector($RacketArea))
		var currot = Quaternion($playermodel.transform.basis.orthonormalized())
		var tarrot = Quaternion($plrangletarget.transform.basis.orthonormalized())
		var newrot = currot.slerp(tarrot, 0.3)
		newrot.y += -input.aim_direction.x / 6
		newrot.w += -input.aim_direction.x / 6
		$playermodel.transform.basis = Basis(newrot).scaled($playermodel.scale)
	
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
	position.x = clamp(position.x, -PlayerVariables.X_LIMIT, PlayerVariables.X_LIMIT)
	var side = get_player_side()
	var z_clamp = [2 * side, PlayerVariables.Z_LIMIT * side]
	position.z = clamp(position.z, min(z_clamp[0], z_clamp[1]), max(z_clamp[0], z_clamp[1]))
	
	# aim arrow
	if Game.ball.ball_ready or input.action_hold:
		if not $AimArrow.visible:
			$AimArrow/Sprite.scale.x = 0
			$AimArrow/Sprite.scale.y = 0
			$AimArrow/Sprite.position.z = 0
			$AimArrow.show()
		$AimArrow.global_position = global_position * Vector3(1, 0, 1) + Vector3(0, 1, 0)
	
	if (
		Game.window_focus
		and not UI.get_node('Menu').visible
		and not UI.get_node('GameControls').visible
	):
		# camera
		update_camera_transform(0.2)
		
		# aim arrow
		var aim_dir = input.aim_direction
		if input.action_hold:
			var hold_mult = ((PlayerVariables.ACTION_HOLD_TIME -
				input.get_node('RacketHold').time_left) /
				PlayerVariables.ACTION_HOLD_TIME)
			$AimArrow/Sprite.scale.x = hold_mult * 20
			$AimArrow/Sprite.scale.y = hold_mult * 5
			$AimArrow/Sprite.position.z = -hold_mult * 10
			$AimArrow.rotation.y = -aim_dir.x
		else:
			$AimArrow/Sprite.scale.x = aim_dir.y * 20
			$AimArrow/Sprite.scale.y = aim_dir.y * 5
			$AimArrow/Sprite.position.z = -aim_dir.y * 10
			$AimArrow.rotation.y = -aim_dir.x * 0.7
