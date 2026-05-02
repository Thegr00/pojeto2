extends Area3D

# This creates the slot in the Inspector to drop your Marker3D into
@export var respawn_point: Marker3D


func _on_body_exited(body: Node3D) -> void:
	if body.name == "mangas3p":
		print("Player fell out! Triggering the portal manager...")
		
		# Find the portal node using the group
		var portal_node = get_tree().get_first_node_in_group("safe_zone")
		
		if portal_node != null:
			
			# 1. Hide the player immediately so we don't see them falling
			body.visible = false
			
			# 2. Stop their falling momentum
			if body is CharacterBody3D:
				body.velocity = Vector3.ZERO
			elif body is RigidBody3D:
				body.linear_velocity = Vector3.ZERO
				
			# 3. INSTANTLY TELEPORT THE PLAYER TO THE PORTAL
			body.global_position = portal_node.global_position
				
			# 4. Tell the PORTAL to play its sequence!
			if portal_node.has_method("play_portal_intro"):
				portal_node.play_portal_intro()
			else:
				print("ERROR: Found the safe_zone, but it doesn't have the play_portal_intro script!")
				
		else:
			print("ERROR: Could not find the safe_zone group!")
