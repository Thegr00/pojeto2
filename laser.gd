extends Node3D

@onready var raycast = $RayCast3D
@onready var beam = $Beam
@onready var visual_mesh = $Beam/MeshInstance3D
# Make sure this path matches your scene exactly! (e.g., $Beam/CollisionShape3D or $Beam/StaticBody3D/CollisionShape3D)
@onready var collision = $Beam/StaticBody3D/CollisionShape3D

# 1. Added your audio node reference
@onready var laser_sound = $LaserSound

func _ready():
	# Stop the raycast from hitting the Beam body
	raycast.add_exception(beam)
	
	# Turn off the laser temporarily
	collision.disabled = true
	beam.visible = false
	
	# Spin the trap randomly
	rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	
	# Wait one frame for the physics world to fully load (Fixes dss/space state errors)
	await get_tree().physics_frame
	_setup_laser()

func _setup_laser():
	# Shoot UP 
	raycast.target_position = Vector3(0, 100, 0)
	raycast.force_raycast_update()
	var hit_up = raycast.get_collision_point() if raycast.is_colliding() else null
	
	# Shoot DOWN 
	raycast.target_position = Vector3(0, -100, 0)
	raycast.force_raycast_update()
	var hit_down = raycast.get_collision_point() if raycast.is_colliding() else null
	
	if hit_up != null and hit_down != null:
		var distance = hit_up.distance_to(hit_down)
		
		if distance < 0.5:
			queue_free()
			return
			
		# --- THE NO-SWAP FIX ---
		# We DO NOT create a new shape. We DO NOT scale the node.
		# We simply change the Y size of the existing BoxShape3D.
		# Because "Local to Scene" is checked, this is 100% safe!
		collision.shape.size.y = distance
		
		# Stretch the visual mesh (visuals don't crash physics)
		var new_mesh = visual_mesh.mesh.duplicate()
		new_mesh.height = distance
		visual_mesh.mesh = new_mesh
		
		# Move to the center
		beam.global_position = (hit_up + hit_down) / 2.0
		
		# Safely turn the physics back on at the end of the frame
		collision.set_deferred("disabled", false)
		beam.visible = true
		
		# 2. Play the looping sound once the laser is fully built!
		laser_sound.play()
	else:
		queue_free()
