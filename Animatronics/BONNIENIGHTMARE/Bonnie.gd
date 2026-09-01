extends KinematicBody

export var speed = 4.0
export var walk_speed = 2.0 # Vitesse réduite pour le pathfinding (moitié de 4.0)
export var rotation_speed = 8.0

onready var player = get_node("../Player")
onready var raycast = $RayCast
onready var anim = $AnimationPlayer
onready var nav_node = get_tree().get_root().find_node("Navigation", true, false)

var is_player_in_range = false
var is_jumpscare_triggered = false
var is_stunned = false
var velocity = Vector3.ZERO

# Variables pour la Navigation
var path = []
var path_index = 0

# Variables pour la rotation fluide pendant le stun
var is_turning_180 = false
var target_rotation_basis = Basis()

func _ready():
	if raycast:
		raycast.add_exception(self)
	call_deferred("go_to_random_point")

func _physics_process(delta):
	if is_jumpscare_triggered or not is_instance_valid(player): 
		return

	# Si l'ennemi est étourdi (mur touché), il fait sa rotation fluide et sa pause
	if is_stunned:
		velocity.x = 0
		velocity.z = 0
		velocity.y -= 20.0 * delta
		velocity = move_and_slide(velocity, Vector3.UP)
		
		if is_turning_180:
			transform.basis = transform.basis.slerp(target_rotation_basis, rotation_speed * delta)
		return

	# 1. Vérification de la vue via le RayCast (protégé par "not is_stunned")
	var can_see_player = false
	if raycast and raycast.enabled and not is_stunned:
		raycast.look_at(player.global_transform.origin, Vector3.UP)
		raycast.force_raycast_update()
		if raycast.is_colliding() and raycast.get_collider() == player:
			can_see_player = true

	# 2. Si le joueur est repéré : Poursuite directe (Vitesse max)
	if is_player_in_range or can_see_player:
		path.clear()
		
		var self_pos = global_transform.origin
		var target_pos = player.global_transform.origin
		target_pos.y = self_pos.y
		
		var dir = (target_pos - self_pos).normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		
		rotate_towards(dir, delta)
		
		if has_node("AnimationPlayer"):
			anim.play("Jack_O_Bonnie--Charge")
			
	else:
		# Remet le RayCast droit devant lui en mode recherche
		if raycast:
			raycast.rotation = Vector3.ZERO
			
		# 3. Sinon, il suit son chemin de navigation (mode recherche - Vitesse réduite)
		if path.size() > 0 and path_index < path.size():
			navigate_along_path(delta)
		else:
			go_to_random_point()

	# Application de la gravité et du mouvement
	velocity.y -= 20.0 * delta
	velocity = move_and_slide(velocity, Vector3.UP)

	# Si l'ennemi touche physiquement un mur
	if is_on_wall() and not is_stunned:
		trigger_wall_stun_and_turn()

func go_to_random_point():
	if not nav_node:
		return
	
	var random_offset = Vector3(rand_range(-12, 12), 0, rand_range(-12, 12))
	var random_target = global_transform.origin + random_offset
	
	path = nav_node.get_simple_path(global_transform.origin, random_target, true)
	path_index = 0
	
	if path.size() == 0:
		var fallback_dir = -transform.basis.z if randf() > 0.5 else transform.basis.x
		path = [global_transform.origin + fallback_dir * 4.0]

func navigate_along_path(delta):
	if path_index < path.size():
		var target_point = path[path_index]
		target_point.y = global_transform.origin.y
		
		var self_pos = global_transform.origin
		var distance = self_pos.distance_to(target_point)
		
		if distance < 0.5:
			path_index += 1
		else:
			var dir = (target_point - self_pos).normalized()
			# Utilise walk_speed (la moitié de la vitesse) au lieu de speed
			velocity.x = dir.x * walk_speed
			velocity.z = dir.z * walk_speed
			rotate_towards(dir, delta)
			
			if has_node("AnimationPlayer"):
				# Remplace par une animation de marche si tu en as une, ou garde Idle/Walk
				anim.play("Jack_O_Bonnie--Walk") # Change le nom si ton anim de marche s'appelle différemment
	else:
		path.clear()

func trigger_wall_stun_and_turn():
	is_stunned = true
	velocity.x = 0
	velocity.z = 0
	path.clear()
	
	if has_node("AnimationPlayer"):
		anim.play("Jack_O_Bonnie--Idle")
		
	# Pendant le stun : RayCast pointe vers le bas
	if raycast:
		raycast.rotation = Vector3.ZERO
		raycast.cast_to = Vector3(0, -2.0, 0)
		raycast.force_raycast_update()
		
	# 1. Attente de 4 secondes immobile
	yield(get_tree().create_timer(4.0), "timeout")
	
	# 2. On prépare la rotation 180° avec une vitesse plus lente
	var backward_dir = transform.basis.z
	target_rotation_basis = transform.looking_at(global_transform.origin + backward_dir, Vector3.UP).basis
	is_turning_180 = true
	
	var old_rot_speed = rotation_speed
	rotation_speed = 2.5 
	
	# Attente de 4 secondes supplémentaires (total 8s) pendant lesquelles il tourne
	yield(get_tree().create_timer(4.0), "timeout")
	
	is_turning_180 = false
	rotation_speed = old_rot_speed
	
	# Fin du stun : on remet le RayCast en face (dos à toi)
	if raycast:
		raycast.rotation = Vector3.ZERO
		raycast.cast_to = Vector3(0, 0, -10)
		raycast.force_raycast_update()
		
	is_stunned = false
	
	# 3. Reprise du comportement aléatoire normal
	go_to_random_point()

func rotate_towards(dir, delta):
	if dir.length() > 0.1:
		var target_basis = transform.looking_at(global_transform.origin + dir, Vector3.UP).basis
		transform.basis = transform.basis.slerp(target_basis, rotation_speed * delta)

# --- Gestion des zones ---

func _on_SeeArea_body_entered(body):
	if body == player or body.name == "Player":
		is_player_in_range = true
		if has_node("Seen!"):
			$"Seen!".play()

func _on_SeeArea_body_exited(body):
	if body == player or body.name == "Player":
		is_player_in_range = false

func _on_JumpscareArea_body_entered(body):
	if not is_jumpscare_triggered and (body == player or body.name == "Player"):
		trigger_jumpscare()

func trigger_jumpscare():
	is_jumpscare_triggered = true
	
	if has_node("AnimationPlayer"):
		anim.play("Jack_O_Bonnie--Jumpscare")
		
	if has_node("Jumpscared!"):
		$"Jumpscared!".play()
	elif has_node("Jumpscare"):
		get_node("Jumpscare").play()
		
	var music_bus = AudioServer.get_bus_index("MUSIC")
	if music_bus != -1:
		AudioServer.set_bus_volume_db(music_bus, -80)
		
	if player:
		var player_transform = player.global_transform
		var forward = -player_transform.basis.z.normalized()
		var new_position = player_transform.origin + forward * 1.5
		new_position.y = global_transform.origin.y
		global_transform.origin = new_position
		
		if global_transform.origin.distance_to(player_transform.origin) > 0.1:
			look_at(player_transform.origin, Vector3.UP)
			
	speed = 0
	yield(get_tree().create_timer(0.6), "timeout")
	get_tree().reload_current_scene()
