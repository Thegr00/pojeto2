extends CanvasLayer

@onready var label = $Label

@export var total_rings: int = 5
var rings_caught: int = 0

# We use this to track what part of the level we are currently in
var current_phase: String = "rings" 

func _ready() -> void:
	update_text()

func ring_collected() -> void:
	if current_phase == "rings":
		rings_caught += 1
		update_text()
		
		# If we hit the max rings, immediately start the next objective!
		if rings_caught >= total_rings:
			start_target_objective()

func update_text() -> void:
	# Change the text based on what phase we are in
	if current_phase == "rings":
		label.text = "Objective: Collect Rings! (" + str(rings_caught) + "/" + str(total_rings) + ")"
	elif current_phase == "target":
		label.text = "Objective: Reach the Target!"
	
	# The UI pop animation
	var pop_tween = create_tween()
	pop_tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.1)
	pop_tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.1)

func start_target_objective() -> void:
	current_phase = "target"
	update_text()
	
	# You can add code here later to make the target visible, 
	# play a sound effect, or spawn an arrow pointing to it!
