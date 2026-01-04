extends KinematicBody

export var speed = 4.0
onready var player = get_node("../Player")

var is_player_in_range = false
var is_jumpscare_triggered = false
var velocity = Vector3.ZERO

func _on_SeeArea_body_entered(body):
	if body.name == "Player":
		is_player_in_range = true
		$"Seen".play()
		$"Steps".play()

func _on_SeeArea_body_exited(body):
	if body.name == "Player":
		is_player_in_range = false
		$"Steps".stop()

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

func _physics_process(delta):
	if not is_instance_valid(player) or is_jumpscare_triggered:
		return
	
	if is_on_wall():
		velocity = Vector3.ZERO
		$AnimationPlayer.play("Jack_O_Bonnie--Idle")
		$"Steps".stop()
		return
	
	if is_player_in_range:
		var self_pos = global_transform.origin
		var target_pos = player.global_transform.origin
		target_pos.y = self_pos.y
	
		var direction = (target_pos - self_pos).normalized()
		velocity = direction * speed
		velocity.y = 0
	
		move_and_slide(velocity, Vector3.UP)
		look_at(target_pos, Vector3.UP)
		$AnimationPlayer.play("Jack_O_Bonnie--Charge")
	else:
		velocity = Vector3.ZERO
		$AnimationPlayer.play("Jack_O_Bonnie--Idle")
		$"Steps".stop()
