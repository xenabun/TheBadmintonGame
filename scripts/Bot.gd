extends CharacterBody3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var speed = PlayerVariables.BASE_SPEED
var throw_power = PlayerVariables.MAX_POWER
var prev_direction = Vector3.ZERO
var stamina = PlayerVariables.MAX_STAMINA
var desired_position = null
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
	var momentum = 1
	if not Game.ball.ball_ready:
		if Game.ball.last_interact != name:
			## jumping
			momentum = 0.1
			desired_position = Vector3(Game.ball.get_land_x(), position.y, Game.ball.get_land_z())
		else:
			if desired_position:
				desired_position = null
			if target_position:
				target_position = null
	else:
		desired_position = Vector3(player.position.x +
				player.velocity.x * delta, position.y, (player.position.z +
				player.velocity.z * delta) - PlayerVariables.MAX_POWER * 0.66)
	if desired_position:
		target_position = lerp(position, desired_position, momentum)
		if abs(desired_position.x - target_position.x) <= 0.1:
			target_position.x = desired_position.x
		if abs(desired_position.z - target_position.z) <= 0.1:
			target_position.z = desired_position.z
		
		direction = position.direction_to(target_position)
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
		$playermodel.transform.basis = Basis(newrot).scaled($playermodel.scale)
	
	# sprint
	var dist_to_tar_pos = 0
	if target_position:
		dist_to_tar_pos = position.distance_to(target_position)
	if (PlayerVariables.MAX_SPEED <= dist_to_tar_pos and
			not Game.ball.ball_ready and
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
	if target_position:
		if abs(target_position.x - position.x) <= 0.2:
			position.x = target_position.x
		if abs(target_position.z - position.z) <= 0.2:
			position.z = target_position.z
	position.x = clamp(position.x, -PlayerVariables.X_LIMIT, PlayerVariables.X_LIMIT)
	position.z = clamp(position.z, -PlayerVariables.Z_LIMIT, -2)
