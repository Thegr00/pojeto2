extends CanvasLayer

@onready var label = $Label
@export var transition_rect: ColorRect
signal tutorial_finished
signal rings_finished

# === 🚀 SCENE TRANSITION CONFIGURATION ===
@export var loading_screen_path: String = "res://LoadingScreen.tscn" # Path to your loading screen
# ========================================

var player: Node3D
var current_objective: int = 0 
@export var total_rings: int = 9
var rings_caught: int = 0
@export var target_y_level: float = 40.0 

var active_fade_tween: Tween

# --- NEW TRICK VARIABLES ---
var pressed_q: bool = false
var pressed_e: bool = false

func _ready() -> void:
	player = get_tree().current_scene.find_child("mangas3p", true, false)
	if player == null:
		print("ERROR: Objective UI couldn't find the player!")
	update_objective_text()

func _process(_delta: float) -> void:
	if player == null: return 
	
	match current_objective:
		0: 
			if Input.is_physical_key_pressed(KEY_A): advance_objective()
		1: 
			if Input.is_physical_key_pressed(KEY_D): advance_objective()
		2: 
			if Input.is_physical_key_pressed(KEY_S): advance_objective()
		3: 
			if Input.is_physical_key_pressed(KEY_W): advance_objective()
		4: 
			if player.global_position.y <= target_y_level: finish_all_objectives()
		6: # --- NEW ADVANCED PHASE CHECK ---
			var changed = false
			if not pressed_q and Input.is_physical_key_pressed(KEY_Q):
				pressed_q = true
				changed = true
			if not pressed_e and Input.is_physical_key_pressed(KEY_E):
				pressed_e = true
				changed = true
				
			# Only update text and check completion if a key was JUST pressed
			if changed:
				update_ring_text()
				check_advanced_completion()

# --- HELPER FUNCTIONS ---

func advance_objective() -> void:
	current_objective += 1 
	update_objective_text()

func update_objective_text() -> void:
	match current_objective:
		0: label.text = "Objective: Hold/press A to go left!"
		1: label.text = "Objective: Hold/press D to go right!"
		2: label.text = "Objective: Hold/press S to go back/up!"
		3: label.text = "Objective: Hold/press W to go forward/down!"
		4: label.text = "Objective: Fly down to the surface!"
	
	var pop_tween = create_tween()
	pop_tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.1)
	pop_tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.1)

func finish_all_objectives() -> void:
	current_objective = 999 
	label.text = "Objectives Complete!"
	tutorial_finished.emit() 
	
	await get_tree().create_timer(3.0).timeout
	if current_objective == 999:
		active_fade_tween = create_tween()
		active_fade_tween.tween_property(label, "modulate:a", 0.0, 1.0)

# --- RING PHASE 1 ---

func start_ring_objective() -> void:
	current_objective = 5 
	rings_caught = 0
	
	if active_fade_tween: active_fade_tween.kill()
		
	var force_visible_tween = create_tween()
	force_visible_tween.tween_property(label, "modulate:a", 1.0, 0.01)
	update_ring_text()

func ring_collected() -> void:
	if current_objective == 5:
		rings_caught += 1
		update_ring_text()
		
		if rings_caught >= total_rings:
			finish_ring_objective()
			
	elif current_objective == 6: # --- ADVANCED PHASE ---
		rings_caught += 1
		update_ring_text()
		check_advanced_completion()

func update_ring_text() -> void:
	if current_objective == 5:
		label.text = "Objective: Fly through the rings! (" + str(rings_caught) + "/" + str(total_rings) + ")"
	elif current_objective == 6:
		var q_status = "[X]" if pressed_q else "[ ]"
		var e_status = "[X]" if pressed_e else "[ ]"
		label.text = "Objective: Rings (" + str(rings_caught) + "/" + str(total_rings) + ") | Tricks: Q " + q_status + " E " + e_status
	
	var pop_tween = create_tween()
	pop_tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.1)
	pop_tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.1)

func finish_ring_objective() -> void:
	current_objective = 999 
	label.text = "All rings collected!"
	
	rings_finished.emit() 
	
	await get_tree().create_timer(3.0).timeout
	if current_objective == 999:
		active_fade_tween = create_tween()
		active_fade_tween.tween_property(label, "modulate:a", 0.0, 1.0)

# --- RING PHASE 2 (ADVANCED) ---

func start_advanced_rings(new_total: int) -> void:
	current_objective = 6 
	rings_caught = 0
	total_rings = new_total 
	
	pressed_q = false
	pressed_e = false
	
	if active_fade_tween: active_fade_tween.kill()
		
	var force_visible_tween = create_tween()
	force_visible_tween.tween_property(label, "modulate:a", 1.0, 0.01)
	update_ring_text()

func check_advanced_completion() -> void:
	if rings_caught >= total_rings and pressed_q and pressed_e:
		finish_final_tutorial()

# ⚡ UPDATED: Now triggers the scene change instead of an animation
# ⚡ UPDATED: Now includes the sliding screen wipe transition!
func finish_final_tutorial() -> void:
	current_objective = 999 
	label.text = "Tutorial 100% Complete! You are ready."
	
	# 1. Wait 3 seconds for the player to read the completion text
	await get_tree().create_timer(3.0).timeout
	
	if current_objective == 999:
		# 2. Fade out the tutorial text cleanly
		active_fade_tween = create_tween()
		active_fade_tween.tween_property(label, "modulate:a", 0.0, 1.0)
		await active_fade_tween.finished
		
		# 3. Slide the TransitionRect in from the left!
		# This moves its X position from -2500 to 0 over 1 second.
		var slide_tween = create_tween()
		slide_tween.tween_property(transition_rect, "position:x", 0.0, 1.0).set_trans(Tween.TRANS_SINE)
		
		# Wait for the slide to finish covering the screen
		await slide_tween.finished
		
		# 4. Safety check, then immediately swap to the loading screen behind the black rect!
		if is_inside_tree():
			#get_tree().change_scene_to_file("res://loading_screen.tscn")
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().change_scene_to_file("res://Main_Menu/main_menu.tscn")
