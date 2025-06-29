extends KinematicBody

onready var head = $Head
onready var head_x = $Head/HeadXRotation
onready var camera = $Head/HeadXRotation/Camera
onready var flashlight_light = $Head/HeadXRotation/Flashlight/Spotlight
onready var collider = $CollisionShape

export var cam_rotation_amount : float = 0.2

const DEFAULT_SPEED = 3.0
const RUN_SPEED = 5.0
const CROUCH_SPEED = 1.0
const GRAVITY = 5.0
const H_ACCEL = 6.0
const SENSITIVITY = 0.3

var default_collider_height = 4.0
var crouch_collider_height = 1.0
var default_collider_position = Vector3(0, 1, 0)
var crouch_collider_position = Vector3(0, 0.5, 0)

var speed = DEFAULT_SPEED
var h_velocity = Vector3()
var movement = Vector3()
var gravity_vec = Vector3()

var cam_shaking = false
var shake_time = 0.0
var shake_amplitude = 0.5
var shake_speed = 20.0

var crouch_interp = 0.0
var is_dead = false

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	set_process(true)
	set_physics_process(true)
	set_process_input(true)

func _input(event):
	if event is InputEventMouseMotion:
		head_x.rotation_degrees.x = clamp(head_x.rotation_degrees.x - SENSITIVITY * event.relative.y, -89, 89)
		rotation_degrees.y -= SENSITIVITY * event.relative.x
	elif event is InputEventKey and event.scancode == KEY_F and event.pressed:
		flashlight_light.visible = !flashlight_light.visible
		$Head/HeadXRotation/Flashlight/AudioStreamPlayer3D.play()

func _physics_process(delta):
	if is_dead:
		# reset crouch smoothly and ignore input
		crouch_interp = lerp(crouch_interp, 0.0, 10 * delta)
	else:
		var crouching = Input.is_action_pressed("crouch")
		var target = 0.0
		if crouching:
			target = 1.0
		crouch_interp = lerp(crouch_interp, target, 10 * delta)
	var shape = collider.shape
	if shape is CapsuleShape:
		shape.height = lerp(default_collider_height, crouch_collider_height, crouch_interp)
		collider.shape = shape

	collider.translation = default_collider_position.linear_interpolate(crouch_collider_position, crouch_interp)
	head.position.y = lerp(1.0, 0.5, crouch_interp)

	speed = lerp(DEFAULT_SPEED, CROUCH_SPEED, crouch_interp)
	if Input.is_action_pressed("run") and crouch_interp < 0.1 and not is_dead:
		speed = RUN_SPEED

	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	h_velocity = h_velocity.linear_interpolate(direction * speed, H_ACCEL * delta)

	movement.x = h_velocity.x
	movement.z = h_velocity.z

	if not is_on_floor():
		gravity_vec += Vector3.DOWN * GRAVITY * delta
	else:
		gravity_vec = -get_floor_normal() * GRAVITY

	movement.y = gravity_vec.y
	move_and_slide(movement, Vector3.UP)

	if cam_shaking:
		shake_time += delta
		var shake_x = shake_amplitude * sin(shake_time * shake_speed)
		var shake_y = shake_amplitude * cos(shake_time * shake_speed * 1.5)
		camera.rotation_degrees.x = clamp(head_x.rotation_degrees.x + shake_x, -89, 89)
		camera.rotation_degrees.y += shake_y
	else:
		camera.rotation_degrees = Vector3(head_x.rotation_degrees.x, 0, 0)

func reset_player_height():
	is_dead = true
	crouch_interp = 0.0
	var shape = collider.shape
	if shape is CapsuleShape:
		shape.height = default_collider_height
		collider.shape = shape
	collider.translation = default_collider_position
	head.position.y = 1.0

func _on_JumpscareArea_body_entered(body):
	if body.name == "Player":
		reset_player_height()
		_physics_process(get_physics_process_delta_time())
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		cam_shaking = false
		$Heartbeat.stop()
		camera.rotation_degrees = Vector3.ZERO
		head_x.rotation_degrees = Vector3.ZERO
		head.rotation_degrees = Vector3.ZERO
		for i in range(5):
			camera.rotation_degrees = Vector3(rand_range(-5, 5), rand_range(-5, 5), rand_range(-5, 5))
			yield(get_tree().create_timer(0.05), "timeout")
		camera.rotation_degrees = Vector3.ZERO

func _on_SeeArea_body_entered(body):
	if body.name == "Player":
		cam_shaking = true
		shake_time = 0.0
		$Heartbeat.play()

func _on_SeeArea_body_exited(body):
	if body.name == "Player":
		cam_shaking = false
		camera.rotation_degrees = Vector3(head_x.rotation_degrees.x, 0, 0)
		$Heartbeat.stop()
