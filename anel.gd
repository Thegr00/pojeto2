extends Area3D

func _ready() -> void:
	# This connects the touch sensor via code!
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	# Check if the thing flying through the ring is the player
	if body.name == "mangas3p":
		print("Player flew through a ring!")
		
		# Find our Objective Manager and tell it we got a ring
		var objective_manager = get_tree().current_scene.find_child("ObjectiveUI", true, false)
		
		if objective_manager and objective_manager.has_method("ring_collected"):
			objective_manager.ring_collected()
			
		# Optional: Play a sound effect here!
		
		queue_free()
