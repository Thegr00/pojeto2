extends CanvasLayer

@onready var score_label: Label = $Label/VBoxContainer/Label
@onready var restart_button: Button = $Label/VBoxContainer/RestartButton

# 1. Preload your actual loading screen scene
const LOADING_SCREEN = preload("res://loading_screen.tscn")

# NEW: A safety flag to stop players from spamming the button/spacebar
var is_restarting := false 

func _ready() -> void:
	restart_button.pressed.connect(_on_restart_button_pressed)

func set_final_score(score: int) -> void:
	score_label.text = "Final Score: " + str(score)

# --- NEW: Listen for the Spacebar ---
func _input(event: InputEvent) -> void:
	# Check if the key is space, is being pressed, and isn't just held down (echo)
	if event is InputEventKey and event.keycode == KEY_SPACE and event.pressed and not event.echo:
		_on_restart_button_pressed()

func _on_restart_button_pressed() -> void: 
	# If we are already restarting, ignore any extra clicks or spacebar presses!
	if is_restarting:
		return
	is_restarting = true
	
	# 2. Spawn a clone of the actual loading screen
	var fake_loading_screen = LOADING_SCREEN.instantiate()
	fake_loading_screen.layer = 100 
	add_child(fake_loading_screen)
	
	# 3. Position it off-screen to the right 
	var screen_width = get_viewport().get_visible_rect().size.x
	fake_loading_screen.offset = Vector2(screen_width, 0)
	
	# 4. Swoop the clone in!
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) 
	
	tween.tween_property(fake_loading_screen, "offset", Vector2(0, 0), 0.4)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
		
	# 5. Wait for the swoop to finish...
	await tween.finished
	
	# 6. UNPAUSE THE GAME TREE!
	get_tree().paused = false 
	
	# 7. ...THEN reload the scene! 
	get_tree().reload_current_scene()
