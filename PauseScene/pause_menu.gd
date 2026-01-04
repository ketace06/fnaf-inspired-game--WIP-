extends CanvasLayer

onready var effects = $UI
onready var main_scene = get_tree().current_scene
onready var player = $"../Player"
onready var effects_node = $"../Player/UI/Effects/BackBufferCopy/LensDistortion"
onready var text = $UI/Content/Text

func _ready():
	effects.visible = false
	effects_node.visible = true
	text.visible_characters = 0

var char_speed = 60

func _process(delta):
	if effects.visible:
		if text.visible_characters < text.get_total_character_count():
			text.visible_characters += int(char_speed * delta)

func _unhandled_input(event):
	if event.is_action_pressed("pause"):
		get_tree().paused = !get_tree().paused
	
		if get_tree().paused:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			effects.visible = true
			effects_node.visible = false
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			effects.visible = false
			effects_node.visible = true
			text.visible_characters = 0

func _on_ExitButton_pressed():    
	get_tree().quit()
