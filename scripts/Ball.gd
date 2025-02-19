extends CharacterBody3D

const BASE_PLAYER_POS_Y = 2.412
const SHADOW_SIZE = Vector3(15, 2, 15)

@export var match_id : int = 0

# @export var Level : Node
# @export var Network : Node
# @export var FieldArea : Node
# @export var FloorArea : Node
# @export var NetArea : Node
# @export var Player1Area : Node
# @export var Player2Area : Node

@onready var Level = get_tree().get_root().get_node('Scene/Level')
@onready var Network = get_tree().get_root().get_node('Scene/Network')
@onready var ball_hitbox : Area3D = get_node('Area')
@onready var shadow : Decal = get_node('Shadow')
@onready var shadow_ray : RayCast3D = get_node('ShadowRaycast')

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
			# await get_tree().create_timer(0.5).timeout
			if multiplayer.is_server():
				Game.reset_player_positions(match_id)
			else:
				Game.reset_player_positions.rpc_id(1, match_id)

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

	set_physics_process(false)
	shadow.visible = false
	# $Debug_MaxHeight.visible = Game.debug
	# $Debug_Z.visible = Game.debug
	# $Debug_ZLand.visible = Game.debug
	# $Debug_LaunchHeight.visible = Game.debug

	var current_authority = multiplayer.get_unique_id()
	if Network.Players.has(current_authority):
		var current_authority_player_data = Network.Players[current_authority]
		if current_authority_player_data and current_authority_player_data.has('match_id'):
			print('ball visiblity set for ', current_authority, ': ', match_id == current_authority_player_data.match_id)
			visible = match_id == current_authority_player_data.match_id

func _physics_process(_delta):
	# reset debug
	# if Game.debug and ball_ready:
	# 	for node in get_children():
	# 		if node.name.contains('Debug'):
	# 			node.position = Vector3.ZERO
	
	if get_multiplayer_authority() != multiplayer.get_unique_id(): return
	# if not Game.game_in_progress or ball_ready: return
	if not Game.is_match_in_progress(match_id) or ball_ready: return
	
	# reset when leaves field area
	if not ball_hitbox.overlaps_area(FieldArea):
		set_ball_ready.rpc()
		return
	
	# floor interact
	if ball_hitbox.overlaps_area(FloorArea):
		var p = 0
		if ball_hitbox.overlaps_area(Player1Area):
			p = 1
			# Game.grant_point.rpc(1, match_id)
		elif ball_hitbox.overlaps_area(Player2Area):
			p = 0
			# Game.grant_point.rpc(0, match_id)
		else:
			var pdata = Network.Players[str(last_interact).to_int()]
			p = Game.get_opponent_index(pdata.num - 1)
			# Game.grant_point.rpc(Game.get_opponent_index(pdata.num - 1), match_id)
		if Game.current_game_type == Game.game_type.MULTIPLAYER:
			if multiplayer.get_unique_id() == 1:
				Game.set_players_can_throw(match_id, p + 1)
			else:
				Game.set_players_can_throw.rpc_id(1, match_id, p + 1)
		else:
			Game.set_players_can_throw(match_id, 1)
		Game.grant_point.rpc(p, match_id)
		set_ball_ready.rpc()
		return
	
	# net interact
	if ball_hitbox.overlaps_area(NetArea) and NetArea != ignored_area:
		# Game.print_debug_msg('ball hit net')
		# var player_name = Network.Players[Game.get_opponent_id(get_multiplayer_authority())].username
		# var last_interact_id = str(last_interact).to_int()
		# var opponent_id = Game.get_opponent_id(last_interact_id)
		# var player_name = Network.Players[opponent_id].username
		# var player_name = str(opponent_id)
		# print(last_interact_id, opponent_id, player_name)
		var new_power = power * 0.75
		var new_direction = -direction
		var new_velocity_x = -velocity.x
		bounce_ball.rpc(get_multiplayer_authority(),
				# player_name, new_velocity_x, new_direction, new_power,
				last_interact, new_velocity_x, new_direction, new_power,
				position, NetArea)

	# racket interact
	var overlapped_areas = ball_hitbox.get_overlapping_areas()
	for oarea in overlapped_areas:
		if oarea.name != 'RacketArea': continue
		if oarea == ignored_area: continue
		
		var player = oarea.get_parent()
		var player_name = player.name
		var new_power = player.throw_power
		var new_direction = VectorMath.look_vector(oarea).z
		var aim_x = sin((player.aim_x * PI) / 2)
		var new_velocity_x = aim_x * 30 * -new_direction
		
		bounce_ball.rpc(Game.get_opponent_id(str(player_name).to_int()),
				player_name, new_velocity_x, new_direction, new_power,
				position, oarea)
		break
	
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
		# var floor_normal = $RayCast3D.get_collision_normal()
		# if floor_point: # + floor_normal / 2 != floor_point + floor_normal:
			# $Shadow.look_at_from_position(
			# 		floor_point + floor_normal / 2,
			# 		floor_point + floor_normal,
			# 		Vector3(0, 0, -1)
			# )
		shadow.global_position = floor_point
		# $Shadow.scale = Vector3.ONE * (0.5 + (position.y / 6))
		var height_unit = height / max_height
		shadow.size = SHADOW_SIZE * height_unit
		# shadow.material_override.set_shader_parameter('cube_full_size', size)
		shadow.albedo_mix = height_unit
		shadow.visible = true
	else:
		shadow.visible = false
	
	# if Game.debug:
	# 	$Debug_LaunchHeight.global_position = launch_pos + Vector3(0, get_launch_height(), 0)
	# 	$Debug_MaxHeight.global_position = Vector3(position.x, get_max_height(), position.z)
	# 	$Debug_Z.global_position = Vector3(launch_pos.x, 1, launch_pos.z)
	# 	$Debug_ZLand.global_position = Vector3(get_land_x(), 1, get_land_z())
