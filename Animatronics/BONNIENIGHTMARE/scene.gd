extends Spatial

export var speed = 4.0
onready var player = get_node("../Player")

var is_player_in_range = false
var is_jumpscare_triggered = false

func _ready():
	$SeeArea.connect("body_entered", self, "_on_Area_body_entered")
	$SeeArea.connect("body_exited", self, "_on_Area_body_exited")
	$Sketchfab_model/JumpscareArea.connect("body_entered", self, "_on_JumpscareArea_body_entered")

func _on_Area_body_entered(body):
	if body.name == "Player":
		is_player_in_range = true
		$"Seen!".play()

func _on_Area_body_exited(body):
	if body.name == "Player":
		is_player_in_range = false

func _on_JumpscareArea_body_entered(body):
	if body.name == "Player" and not is_jumpscare_triggered:
		is_jumpscare_triggered = true
		$AnimationPlayer.play("Jack_O_Bonnie--Jumpscare")
		$"Jumpscared!".play()
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("MUSIC"), -80)
		var player_transform = player.global_transform
		var forward = -player_transform.basis.z.normalized()
		var new_position = player_transform.origin + forward
		new_position.y = global_transform.origin.y
		global_transform.origin = new_position
		look_at(player_transform.origin, Vector3.UP)
		speed = 0
		yield(get_tree().create_timer(9.0), "timeout")
		get_tree().reload_current_scene()


func _process(delta):
	if not is_instance_valid(player) or is_jumpscare_triggered:
		return

	if is_player_in_range:
		var self_pos = global_transform.origin
		var target_pos = player.global_transform.origin
		target_pos.y = self_pos.y 

		var direction = (target_pos - self_pos).normalized()
		translation += direction * speed * delta

		look_at(target_pos, Vector3.UP)
		$AnimationPlayer.play("Jack_O_Bonnie--Charge")
	else:
		$AnimationPlayer.play("Jack_O_Bonnie--Idle")
