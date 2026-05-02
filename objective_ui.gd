extends CanvasLayer

@onready var label = $Label
signal tutorial_finished
var player: Node3D
var current_objective: int = 0 
@export var total_rings: int = 9
var rings_caught: int = 0
@export var target_y_level: float = 40.0 

func _ready() -> void:
	player = get_tree().current_scene.find_child("mangas3p", true, false)
	
	if player == null:
		print("ERROR: Objective UI couldn't find the player!")
		
	# Setup the very first text prompt
	update_objective_text()

func _process(_delta: float) -> void:
	if player == null: return # Stop if the player doesn't exist
	
	# The match statement checks what step we are on and only runs that code!
	match current_objective:
		
		0: # STEP 0: Wait for A
			if Input.is_physical_key_pressed(KEY_A):
				advance_objective()
				
		1: # STEP 1: Wait for D
			if Input.is_physical_key_pressed(KEY_D):
				advance_objective()
				
		2: # STEP 2: Wait for W
			if Input.is_physical_key_pressed(KEY_W):
				advance_objective()
				
		3: # STEP 3: Wait for S
			if Input.is_physical_key_pressed(KEY_S):
				advance_objective()
				
		4: # STEP 4: Fly down!
			if player.global_position.y <= target_y_level:
				finish_all_objectives()


# --- HELPER FUNCTIONS ---

func advance_objective() -> void:
	current_objective += 1 # Move to the next step
	update_objective_text()

func update_objective_text() -> void:
	# Update the text based on whatever the current step is
	match current_objective:
		0: label.text = "Objective: Hold/press A to go left!"
		1: label.text = "Objective: Hold/press D to go right!"
		2: label.text = "Objective: Hold/press W to go forward/down!"
		3: label.text = "Objective: Hold/press S to go back/up!"
		4: label.text = "Objective: Fly down to the surface!"
	
	# Play the pop animation every time the text updates
	var pop_tween = create_tween()
	pop_tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.1)
	pop_tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.1)

func finish_all_objectives() -> void:
	current_objective = 999 
	label.text = "Objectives Complete!"
	
	tutorial_finished.emit() 
	
	# Wait 3 seconds
	await get_tree().create_timer(3.0).timeout
	
	# THE FIX: Only fade out if a new objective hasn't started yet!
	if current_objective == 999:
		var fade_tween = create_tween()
		fade_tween.tween_property(label, "modulate:a", 0.0, 1.0)

func start_ring_objective() -> void:
	# TRIPWIRE: If this doesn't show up in the bottom console, the AnimationPlayer isn't calling the function!
	print("DEBUG: start_ring_objective is firing!") 
	
	current_objective = 5 
	rings_caught = 0
	
	# BULLETPROOF VISIBILITY: Reset everything that could possibly hide the text
	label.visible = true
	label.modulate = Color(1, 1, 1, 1) # Force it back to solid white (fully opaque)
	
	update_ring_text()

# The Ring script calls this whenever the player flies through one
func ring_collected() -> void:
	if current_objective == 5:
		rings_caught += 1
		update_ring_text()
		
		if rings_caught >= total_rings:
			finish_ring_objective()

func update_ring_text() -> void:
	label.text = "Objective: Fly through the rings! (" + str(rings_caught) + "/" + str(total_rings) + ")"
	
	# Play the visual pop animation
	var pop_tween = create_tween()
	pop_tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.1)
	pop_tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.1)

func finish_ring_objective() -> void:
	current_objective = 999 
	label.text = "All rings collected!"
	
	await get_tree().create_timer(3.0).timeout
	var fade_tween = create_tween()
	fade_tween.tween_property(label, "modulate:a", 0.0, 1.0)
