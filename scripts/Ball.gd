extends CharacterBody3D

const BASE_PLAYER_POS_Y = 2.412
const SHADOW_SIZE = Vector3(15, 2, 15)

@export var match_id : int = 0

@onready var Level = get_tree().get_root().get_node('Scene/Level')
@onready var Network = get_tree().get_root().get_node('Scene/Network')
@onready var ball_hitbox : Area3D = get_node('Area')
@onready var shadow : Decal = get_node('Shadow')
@onready var shadow_ray : RayCast3D = get_node('ShadowRaycast')
@onready var trajectory_ray : RayCast3D = get_node('TrajectoryRaycast')

var FieldArea
var FloorArea
var NetArea
var Player1Area
var Player2Area

var direction : float = 0.0
var power : float = 0.0
var launch_pos : Vector3 = Vector3.ZERO
var ignored_area
var last_interact : String = ''

func get_launch_height():
	return (BallVariables.BASE_Y + (BallVariables.MAX_Y -
			BallVariables.BASE_Y) * ((power - PlayerVariables.BASE_POWER) /
			(PlayerVariables.MAX_POWER - PlayerVariables.BASE_POWER)))
func get_max_height():
	return launch_pos.y + get_launch_height()
func get_height(z):
	return (get_max_height() - (4.0 * get_launch_height() *
			((abs(launch_pos.z - z) - (power / 2.0)) ** 2.0)) /
			(power ** 2.0))
func get_land_z():
	return ((power / 2.0) * (1.0 + sqrt((get_max_height() -
			BASE_PLAYER_POS_Y) / get_launch_height())) *
			direction + launch_pos.z)
func get_land_x():
	return (launch_pos.x + velocity.x * abs(launch_pos.z - get_land_z()) / 
			(power * (BallVariables.BASE_SPEED_MULT + 
			BallVariables.MAX_SPEED_MULT) / 2))

var ball_ready = true:
	set(value):
		reset_ball()
		ball_ready = value
		if value and Game.is_match_in_progress(match_id):
			# Game.reset_player_positions.rpc_id(1, match_id)
			Game.reset_player_positions.rpc(match_id)

@rpc('any_peer', 'call_local')
func set_ball_ready(value = true):
	ball_ready = value
@rpc("any_peer", 'call_local')
func throw_ball(peer_id : int, player_name : String, new_position : Vector3,
		new_direction : float, new_velocity_x : float, aim_dir_y : float):
	if not peer_id or peer_id < 1 or Game.current_game_type == Game.game_type.SINGLEPLAYER:
		peer_id = 1
	ball_ready = false
	position = new_position
	velocity.x = new_velocity_x
	launch_pos = new_position
	direction = new_direction
	power = (PlayerVariables.BASE_POWER + (PlayerVariables.MAX_POWER -
			PlayerVariables.BASE_POWER) * aim_dir_y)
	last_interact = player_name
	get_node('Trail').emitting = true
	set_multiplayer_authority(peer_id)
	set_physics_process(true)
	ball_hitbox.set_deferred('monitoring', true)
	trajectory_ray.set_deferred('enabled', true)
@rpc('any_peer', 'call_local')
func bounce_ball(peer_id : int, player_name : String, new_velocity_x : float, new_direction : float,
		new_power : float, new_launch_pos : Vector3, oarea):
	if not peer_id or peer_id < 1 or Game.current_game_type == Game.game_type.SINGLEPLAYER:
		peer_id = 1
	velocity.x = new_velocity_x
	launch_pos = new_launch_pos
	direction = new_direction
	power = new_power
	last_interact = player_name
	ignored_area = oarea
	set_multiplayer_authority(peer_id)
func reset_ball():
	ball_hitbox.set_deferred('monitoring', false)
	trajectory_ray.set_deferred('enabled', false)
	set_physics_process(false)
	get_node('Trail').emitting = false
	get_node('Trail').restart()
	ignored_area = null
	velocity = Vector3.ZERO
	position = Vector3(0, -10, 30)

@rpc('any_peer')
func reset_authority():
	set_multiplayer_authority(1)

func _ready():
	FieldArea = Level.get_node('World/FieldArea')
	FloorArea = Level.get_node('World/Floor/Area')
	NetArea = Level.get_node('World/Net/Area')
	Player1Area = Level.get_node('World/Player1Area')
	Player2Area = Level.get_node('World/Player2Area')

	ball_hitbox.monitoring = false
	trajectory_ray.enabled = false
	set_physics_process(false)
	shadow.visible = false

	var current_authority = multiplayer.get_unique_id()
	if Network.Players.has(current_authority):
		var current_authority_player_data = Network.Players[current_authority]
		if current_authority_player_data and current_authority_player_data.has('match_id'):
			print('ball visiblity set for ', current_authority, ': ', match_id == current_authority_player_data.match_id)
			visible = match_id == current_authority_player_data.match_id

func bounce_from_racket(area: Area3D):
	if area == ignored_area: return

	var player = area.get_parent()
	var player_name = player.name
	var new_power = player.throw_power
	var new_direction = VectorMath.look_vector(area).z
	var aim_x = sin((player.aim_x * PI) / 2)
	var new_velocity_x = aim_x * 30 * -new_direction
	bounce_ball.rpc(Game.get_opponent_id(str(player_name).to_int()),
			player_name, new_velocity_x, new_direction, new_power,
			position, area)

func _area_entered(area: Area3D):
	# floor interact
	if area == FloorArea:
		var p = 0
		if ball_hitbox.overlaps_area(Player1Area):
			p = 1
		elif ball_hitbox.overlaps_area(Player2Area):
			p = 0
		else:
			var pdata = Network.Players[str(last_interact).to_int()]
			p = Game.get_opponent_index(pdata.num - 1)
		if Game.current_game_type == Game.game_type.MULTIPLAYER:
			# Game.set_players_can_throw.rpc_id(1, match_id, p + 1)
			# print('calling set_players_can_throw() by ', multiplayer.get_unique_id())
			Game.set_players_can_throw.rpc(match_id, p + 1)
		else:
			Game.set_players_can_throw(match_id, 1)
		Game.grant_point.rpc(p, match_id)
		set_ball_ready.rpc()

	# net interact
	elif area == NetArea and NetArea != ignored_area:
		var new_power = power * 0.5
		var new_direction = -direction
		var new_velocity_x = -velocity.x
		bounce_ball.rpc(get_multiplayer_authority(),
				last_interact, new_velocity_x, new_direction, new_power,
				position, NetArea)

	# racket interact
	elif area.name == 'RacketArea':
		bounce_from_racket(area)

func _area_exited(area: Area3D):
	# reset when leaves field area
	# print('exiting area ', area)
	if area == FieldArea and ball_ready == false:
		# print('!!! ', ball_ready)
		if Game.current_game_type == Game.game_type.MULTIPLAYER:
		# 	# Game.set_players_can_throw.rpc_id(1, match_id, randi_range(1, 2))
		# 	print('Я ХУЕЮ')
			Game.set_players_can_throw.rpc(match_id, randi_range(1, 2))
		else:
			Game.set_players_can_throw(match_id, 1)
		set_ball_ready.rpc()

func _physics_process(delta):
	if get_multiplayer_authority() != multiplayer.get_unique_id(): return
	if not Game.is_match_in_progress(match_id) or ball_ready: return
	
	# racket interact
	if trajectory_ray.enabled:
		trajectory_ray.target_position = position.direction_to(Vector3(
				position.x + velocity.x * delta,
				get_height(position.z + velocity.z * delta),
				position.z + velocity.z * delta))
		if trajectory_ray.is_colliding():
			var area = trajectory_ray.get_collider()
			if area.name == 'RacketArea':
				bounce_from_racket(area)
	
	# position
	move_and_slide()
	var height = get_height(position.z)
	var max_height = get_max_height()
	var height_frac = (BallVariables.BASE_SPEED_MULT +
			(BallVariables.MAX_SPEED_MULT - BallVariables.BASE_SPEED_MULT) *
			abs( 1 - (height - BASE_PLAYER_POS_Y) / max_height ))
	position.y = height
	velocity.z = power * direction * height_frac
	
	# shadow
	if shadow_ray.is_colliding():
		var floor_point = shadow_ray.get_collision_point()
		shadow.global_position = floor_point
		var height_unit = height / max_height
		shadow.size = SHADOW_SIZE * height_unit
		shadow.albedo_mix = height_unit
		shadow.visible = true
	else:
		shadow.visible = false
	
	# if Game.debug:
	# 	$Debug_LaunchHeight.global_position = launch_pos + Vector3(0, get_launch_height(), 0)
	# 	$Debug_MaxHeight.global_position = Vector3(position.x, get_max_height(), position.z)
	# 	$Debug_Z.global_position = Vector3(launch_pos.x, 1, launch_pos.z)
	# 	$Debug_ZLand.global_position = Vector3(get_land_x(), 1, get_land_z())
