extends CharacterBody3D

@export var Level : Node
@export var aim_x = 0
@export var player : Node
@export var match_id : int = 0

@onready var animation_tree = get_node('AnimationTree')
@onready var player_model = get_node('playermodel')
@onready var player_angle_target = get_node('plrangletarget')
@onready var racket_area = get_node('RacketArea')
@onready var racket_cooldown_timer = get_node('RacketCooldown')
@onready var sprint_timer = get_node('Sprint')

var ball
var noise
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var speed = PlayerVariables.BASE_SPEED
var throw_power = PlayerVariables.MAX_POWER
var prev_direction = Vector3.ZERO
var stamina = PlayerVariables.MAX_STAMINA
var target_position
var exhausted = false
var sprinting = false
var can_play = true
var can_throw = false

func _on_sprint_timeout():
	sprinting = false
var racket_cooldown = false:
	set(value):
		racket_cooldown = value
		racket_area.monitorable = value
		if Game.debug:
			$RacketArea/CSGBox3D.visible = value
		if value:
			racket_cooldown_timer.start()
func _on_racket_cooldown_timeout():
	racket_cooldown = false

func set_can_throw(value):
	can_throw = value

func reset_position():
	# TODO: add bot can_throw logic and make bot be able to throw ball
	var player_index = 2
	if true: # not can_throw:
		player_index = Game.get_opponent_index(player_index)
	var player_round_score = Game.get_player_round_score(match_id, player_index)
	var side = 'Even' if player_round_score % 2 == 0 else 'Odd'
	var spawn_point = Level.get_node('World/Player2Spawn' + side)
	position = spawn_point.position
	rotation = spawn_point.rotation

func _ready():
	ball = Game.get_ball_by_match_id(match_id)
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.0001
	$Debug_Dest.visible = Game.debug
	$AimArrow.visible = Game.debug
	$SprintingLabel.visible = Game.debug
	$StaminaLabel.visible = Game.debug
	$RacketArea/CSGBox3D.hide()

func _physics_process(delta):
	if not Game.is_match_in_progress(match_id):
		if animation_tree.active:
			animation_tree.active = false
		return
	if not animation_tree.active:
		animation_tree.active = true
	
	# racket hold
	var hold_mult = abs(position.z) / PlayerVariables.Z_LIMIT
	throw_power = (PlayerVariables.BASE_POWER +
			(PlayerVariables.MAX_POWER -
			PlayerVariables.BASE_POWER) * hold_mult)
	
	# gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
		animation_tree['parameters/WalkScale/scale'] = move_toward(
				animation_tree['parameters/WalkScale/scale'], 0, 0.02)
	else:
		animation_tree['parameters/WalkScale/scale'] = move_toward(
				animation_tree['parameters/WalkScale/scale'], 1, 0.1)
	
	# get direction
	var direction = Vector3.ZERO
	if ball != null and not ball.ball_ready:
		if ball.last_interact != name:
			target_position = Vector3(ball.get_land_x(), position.y, ball.get_land_z())
		else:
			if target_position:
				target_position = null
	else:
		target_position = Vector3(player.position.x + player.aim_x * 30 +
				player.velocity.x * delta, position.y, (player.position.z +
				player.velocity.z * delta) - PlayerVariables.MAX_POWER * 0.66)
	if target_position:
		direction = position.direction_to(target_position).normalized()
		if Game.debug:
			$Debug_Dest.global_position = target_position
	
	# racket
	if ball != null:
		var ball_dist = (position * Vector3(1, randf() * 0.8, 1)).distance_to(
				ball.position * Vector3(1, randf() * 0.8, 1))
		if not racket_cooldown and ball_dist <= 4:
			racket_cooldown = true
			animation_tree['parameters/RacketSwing/request'] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
	
	# animation
	var blend_amount = 0
	if direction.length() > 0:
		if sprinting and not exhausted and stamina > 0:
			blend_amount = 1
		else:
			blend_amount = 0.5
		if not racket_cooldown:
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
	
	if racket_cooldown:
		player_angle_target.look_at(player_angle_target.global_position + VectorMath.look_vector(racket_area))
		var currot = Quaternion(player_model.transform.basis.orthonormalized())
		var tarrot = Quaternion(player_angle_target.transform.basis.orthonormalized())
		var newrot = currot.slerp(tarrot, 0.3)
		newrot.y += -aim_x / 4.0
		newrot.w += -aim_x / 4.0
		player_model.transform.basis = Basis(newrot).scaled(player_model.scale)
	
	# sprint
	if (target_position and ball != null and ball.launch_pos != Vector3.ZERO and
			not ball.ball_ready and not sprinting and 
			not exhausted and stamina > 0):
		var time_to_reach_target = (position.distance_to(target_position) /
				PlayerVariables.MAX_SPEED)
		var time_for_ball_to_land = (ball.position.distance_to(target_position) /
				(ball.power * (BallVariables.BASE_SPEED_MULT +
				BallVariables.MAX_SPEED_MULT) / 2))
		if time_to_reach_target > time_for_ball_to_land:
			sprinting = true
			sprint_timer.start()
	if Game.debug:
		if exhausted:
			$SprintingLabel.text = 'exhausted'
			$SprintingLabel.modulate = '#ff0000'
		else:
			if sprinting:
				$SprintingLabel.text = 'sprinting'
				$SprintingLabel.modulate = '#00ff00'
			else:
				$SprintingLabel.text = 'not sprinting'
				$SprintingLabel.modulate = '#676767'
	
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
	
	# stamina
	if sprinting and not exhausted and direction.length() > 0:
		stamina = max(stamina - PlayerVariables.STAMINA_DELPETION, 0)
		if stamina <= 0:
			sprinting = false
			exhausted = true
	else:
		stamina = min(stamina + PlayerVariables.STAMINA_REGEN,
				PlayerVariables.MAX_STAMINA / 2)
		if stamina >= PlayerVariables.MAX_STAMINA / 2:
			exhausted = false
	if Game.debug:
		var stamina_text = ''
		var stamina_amount = floor(stamina + 0.5) / 5
		for i in stamina_amount:
			stamina_text += 'i'
		$StaminaLabel.text = '[' + stamina_text + ']'
	
	# velocity
	var vel = direction * Vector3(1, 0, 1) * speed
	velocity = Vector3(vel.x, velocity.y, vel.z)
	
	# position
	move_and_slide()
	if target_position:
		if abs(target_position.x - position.x) <= speed * delta:
			position.x = target_position.x
		if abs(target_position.z - position.z) <= speed * delta:
			position.z = target_position.z
	position.x = clamp(position.x, -PlayerVariables.X_LIMIT, PlayerVariables.X_LIMIT)
	position.z = clamp(position.z, -PlayerVariables.Z_LIMIT, -2)
	
	# aim arrow
	var x_frac = (position.x - player.position.x) / PlayerVariables.X_LIMIT
	var noise_offset = noise.get_noise_1d(float(Time.get_ticks_msec()))
	var aim_help = player.position.x / PlayerVariables.X_LIMIT
	aim_x = (x_frac / 3) + (noise_offset / 2 + aim_help / 4)
	if Game.debug:
		$AimArrow.rotation.y = -sin((aim_x * PI) / 2)
