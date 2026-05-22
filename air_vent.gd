extends Area3D

@export var updraft_speed: float = 30.0 

func _on_body_entered(body: Node3D) -> void:
	print("SOMETHING TOUCHED THE VENT: ", body.name) # Tells us if the hitbox works
	
	if body.is_in_group("Player"):
		print("IT IS THE PLAYER!") # Tells us the group is correct
		
		if body.has_method("enter_wind"):
			print("PLAYER HAS THE METHOD! LAUNCHING!") # Tells us the function name matches
			body.enter_wind(updraft_speed)


func _on_body_exited(body: Node3D) -> void:
	print("SOMETHING LEFT THE VENT") 
	if body.is_in_group("Player"):
		if body.has_method("exit_wind"):
			print("TURNING OFF THE WIND") 
			body.exit_wind()
