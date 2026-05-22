extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	print("RING WAS TOUCHED BY: ", body.name) 
	
	if body.is_in_group("Player"):
		print("THE PLAYER IS IN THE GROUP!") 
		
		var objective_manager = get_tree().current_scene.find_child("ObjectiveUI", true, false)
		
		if objective_manager:
			print("FOUND THE OBJECTIVE UI!") 
			
			if objective_manager.has_method("ring_collected"):
				print("SUCCESS! ADDING RING AND DELETING!")
				objective_manager.ring_collected()
				queue_free()
			else:
				print("ERROR: UI found, but it doesn't have the ring_collected() function.")
		else:
			print("ERROR: Could not find a node named exactly 'ObjectiveUI' in this level.")
