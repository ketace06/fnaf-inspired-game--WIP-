extends KinematicBody

export var speed = 4.0
export var wander_radius = 10.0
export var wander_delay = 2.0

onready var player = get_node("../Player")
onready var raycast = $RayCast
onready var navigation = get_node("../Navigation")

var velocity = Vector3.ZERO
var path = []
var path_index = 0
var wander_target = Vector3.ZERO
var is_player_in_range = false
var is_jumpscare_triggered = false
var start_position = Vector3.ZERO
var gravity = -9.8
var navigation_delay = 5.0
var navigation_timer = 0.0
var can_navigate = false
var path_timer = 0.0
var path_update_delay = 0.3

func _ready():
	start_position = global_transform.origin
	navigation_timer = navigation_delay

func _on_JumpscareArea_body_entered(body):
	if body.name == "Player" and not is_jumpscare_triggered:
		is_jumpscare_triggered = true
		$AnimationPlayer.play("Jack_O_Bonnie--Jumpscare")
		$"Jumpscare".play()
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("MUSIC"), -80)
		$"Steps".stop()
		var player_transform = player.global_transform
		var forward = -player_transform.basis.z.normalized()
		var new_position = player_transform.origin + forward
		new_position.y = global_transform.origin.y
		global_transform.origin = new_position
		look_at(player_transform.origin, Vector3.UP)
		speed = 0
		yield(get_tree().create_timer(2), "timeout")
		get_tree().quit()

func calculate_path(target_position):
	var start = navigation.get_closest_point(global_transform.origin)
	var end = navigation.get_closest_point(target_position)
	path = navigation.get_simple_path(start, end)
	path_index = 0

func choose_wander_target():
	var random_offset = Vector3(
		rand_range(-wander_radius, wander_radius),
		0,
		rand_range(-wander_radius, wander_radius)
	)
	wander_target = global_transform.origin + random_offset
	calculate_path(wander_target)

func move_along_path(current_speed):
	if path.size() == 0:
		return
	var target = path[path_index]
	var direction = (target - global_transform.origin)
	direction.y = 0
	if direction.length() < 0.2:
		path_index += 1
		if path_index >= path.size():
			path = []
			return
		target = path[path_index]
		direction = (target - global_transform.origin)
	velocity.x = direction.normalized().x * current_speed
	velocity.z = direction.normalized().z * current_speed
	look_at(target, Vector3.UP)

func _physics_process(delta):
	if not is_instance_valid(player) or is_jumpscare_triggered:
		return

	is_player_in_range = raycast.is_colliding() and raycast.get_collider() == player

	if is_player_in_range:
		path_timer -= delta
		if path_timer <= 0.0:
			calculate_path(player.global_transform.origin)
			path_timer = path_update_delay
		move_along_path(speed)
		$AnimationPlayer.play("Jack_O_Bonnie--Charge")
		if not $"Steps".playing:
			$"Steps".play()
	else:
		if not can_navigate:
			navigation_timer -= delta
			if navigation_timer <= 0.0:
				can_navigate = true

		if can_navigate:
			if path.size() == 0:
				yield(get_tree().create_timer(wander_delay), "timeout")
				choose_wander_target()
			else:
				move_along_path(speed * 0.5)
				$AnimationPlayer.play("Jack_O_Bonnie--Walk")
				if not $"Steps".playing:
					$"Steps".play()

	velocity.y += gravity * delta
	velocity = move_and_slide(velocity, Vector3.UP)
