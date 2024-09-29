extends CharacterBody3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var speed = PlayerVariables.BASE_SPEED
var throw_power = PlayerVariables.MAX_POWER
var prev_direction = Vector3.ZERO
var stamina = PlayerVariables.MAX_STAMINA
var exhausted = false
var sprinting = false
var racket_cooldown = false:
	set(value):
		racket_cooldown = value
		$RacketArea.monitorable = value
		if value: $RacketCooldown.start()

@onready var ball = get_parent().get_node('Ball')
@onready var player = get_parent().get_node('Player')

func _on_sprint_timeout():
	sprinting = false
func _on_racket_cooldown_timeout():
	racket_cooldown = false

func _physics_process(delta):
	if not Game.game_in_progress:
		$AnimationTree.active = false
		return
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
	var target_position = null
	if not player.get('ball_ready'):
		if ball.get('last_interact') != name:
			## jumping
			target_position = Vector3(ball.position.x,
					position.y, ball.get_land_z())
	else:
		target_position = Vector3(player.position.x +
				player.velocity.x * delta, position.y, (player.position.z +
				player.velocity.z * delta) - PlayerVariables.MAX_POWER * 0.66)
	if target_position:
		var d = (position * Vector3(1, 0, 1)).distance_to(
				target_position * Vector3(1, 0, 1))
		if d > 0.05:
			direction = (position.direction_to(target_position) * Vector3(1, 0, 1))
	
	# normalize direction
	if abs(direction.x) <= 0.1: direction.x = 0
	if abs(direction.z) <= 0.1: direction.z = 0
	direction = direction.normalized()
	
	# racket
	var ball_dist = position.distance_to(ball.position)
	if ball_dist <= 4 and not racket_cooldown:
		racket_cooldown = true
		$AnimationTree['parameters/RacketSwing/request'] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
	
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
		var currot = Quaternion($botmodel.transform.basis.orthonormalized())
		var tarrot = Quaternion($plrangletarget.transform.basis.orthonormalized())
		var newrot = currot.slerp(tarrot, 0.2)
		$botmodel.transform.basis = Basis(newrot).scaled($botmodel.scale)
	
	# sprint
	var dist = 0
	if target_position != null:
		dist = position.distance_to(target_position)
	if (PlayerVariables.MAX_SPEED <= dist and
			not player.get('ball_ready') and
			not sprinting and not exhausted and stamina > 0):
		sprinting = true
		$Sprint.start()
	
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
				PlayerVariables.MAX_STAMINA)
		if stamina >= PlayerVariables.MAX_STAMINA:
			exhausted = false
	
	# velocity
	var vel = Vector3(sign(direction.x), 0, sign(direction.z)).normalized() * speed
	velocity = Vector3(vel.x, velocity.y, vel.z)
	
	# position
	move_and_slide()
	position.x = clamp(position.x, -PlayerVariables.X_LIMIT, PlayerVariables.X_LIMIT)
	position.z = clamp(position.z, -PlayerVariables.Z_LIMIT, -2)
