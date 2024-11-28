extends CharacterBody3D

@export var aim_x = 0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var speed = PlayerVariables.BASE_SPEED
var throw_power = PlayerVariables.MAX_POWER
var prev_direction = Vector3.ZERO
var stamina = PlayerVariables.MAX_STAMINA
var target_position = null
var exhausted = false
var sprinting = false
var racket_cooldown = false:
	set(value):
		racket_cooldown = value
		$RacketArea.monitorable = value
		if Game.debug: $RacketArea/CSGBox3D.visible = value
		if value:
			$RacketCooldown.start()

@onready var Level = get_tree().get_first_node_in_group('Level_root')
@export var player :Node = null

func _on_sprint_timeout():
	sprinting = false
func _on_racket_cooldown_timeout():
	racket_cooldown = false

func _reset_position():
	var spawn_point = Level.get_node('World/Player2Spawn')
	position = spawn_point.position
	rotation = spawn_point.rotation

func _ready():
	$Debug_Dest.visible = Game.debug
	$AimArrow.visible = Game.debug
	$SprintingLabel.visible = Game.debug
	$StaminaLabel.visible = Game.debug
	$RacketArea/CSGBox3D.hide()

func _physics_process(delta):
	if not Game.game_in_progress:
		if $AnimationTree.active:
			$AnimationTree.active = false
		return
	if not $AnimationTree.active:
		$AnimationTree.active = true
	
	# racket hold
	var hold_mult = abs(position.z) / PlayerVariables.Z_LIMIT
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
	
	# get direction
	var direction = Vector3.ZERO
	if not Game.ball.ball_ready:
		if Game.ball.last_interact != name:
			## jumping
			target_position = Vector3(Game.ball.get_land_x(), position.y, Game.ball.get_land_z())
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
	var ball_dist = (position * Vector3(1, randf() * 0.8, 1)).distance_to(
			Game.ball.position * Vector3(1, randf() * 0.8, 1))
	if not racket_cooldown and ball_dist <= 4:
		racket_cooldown = true
		$AnimationTree['parameters/RacketSwing/request'] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
	
	# animation
	var blend_amount = 0
	if direction.length() > 0:
		if sprinting and not exhausted and stamina > 0:
			blend_amount = 1
		else:
			blend_amount = 0.5
		if not racket_cooldown:
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
	if racket_cooldown:
		$plrangletarget.look_at($plrangletarget.global_position + VectorMath.look_vector($RacketArea))
		var currot = Quaternion($playermodel.transform.basis.orthonormalized())
		var tarrot = Quaternion($plrangletarget.transform.basis.orthonormalized())
		var newrot = currot.slerp(tarrot, 0.3)
		newrot.y += -aim_x / 4.0
		newrot.w += -aim_x / 4.0
		$playermodel.transform.basis = Basis(newrot).scaled($playermodel.scale)
	
	# sprint
	if (target_position and Game.ball.launch_pos != Vector3.ZERO and
			not Game.ball.ball_ready and not sprinting and 
			not exhausted and stamina > 0):
		var time_to_reach_target = (position.distance_to(target_position) /
				PlayerVariables.MAX_SPEED)
		var time_for_ball_to_land = (Game.ball.position.distance_to(target_position) /
				(Game.ball.power * (BallVariables.BASE_SPEED_MULT +
				BallVariables.MAX_SPEED_MULT) / 2))
		if time_to_reach_target > time_for_ball_to_land:
			sprinting = true
			$Sprint.start()
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
	aim_x = x_frac / 3
	if Game.debug:
		$AimArrow.rotation.y = -sin((aim_x * PI) / 2)
