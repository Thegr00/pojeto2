extends CharacterBody3D

const GAME_OVER_SCREEN = preload("res://game_over_screen.tscn")

@export_group("Flight Speed")
@export var max_speed = 60.0
@export var min_speed = 15.0 # This is your "Cruising Speed"
@export var dive_acceleration = 30.0  
@export var up_deceleration = 45.0 # Lose speed much faster when climbing
@export var max_stall_gravity = 5.0 # Gravity is now much less strong/punishing
@export var stall_nose_down_speed = 1.5 # Smoother nose drop to match the lower gravity

@export_group("Mouse Aim Settings")
@export var mouse_sensitivity: float = 0.003
@export var body_turn_speed: float = 15.0 

@export_group("WASD Banking Settings")
@export var max_roll_angle: float = 1.0 # ~55 degrees max tilt for ROLL (A/D)
@export var max_pitch_angle: float = 0.52 # ~30 degrees max tilt for PITCH (W/S)
@export var roll_tilt_speed: float = 3.0 # Smoother speed for roll banks
@export var pitch_tilt_speed: float = 2 # Slower speed for pitch tilts
@export var bank_turn_speed: float = 1.8 # How fast A/D actively turns the camera

@export_group("Camera")
@onready var pivot = $"cam origin"
@onready var camera = $"cam origin/SpringArm3D/CABECA"
@onready var spring_arm = $"cam origin"/SpringArm3D
@export var cam_offset_amount: float = 0.5  
@export var cam_offset_speed: float = 3.0

@onready var anim_player: AnimationPlayer = $Gajo/AnimationPlayer
@onready var wind_particles = $"cam origin/AshSnowFall"
@export var mesh_container: Node3D
@onready var proximity_cast: ShapeCast3D = $ShapeCast3D
@onready var crash_sound: AudioStreamPlayer = $CrashSound

var current_speed = 10.0
var cam_yaw: float = 0.0
var cam_pitch: float = 0.0
var current_roll_angle: float = 0.0
var current_pitch_angle: float = 0.0
var is_doing_trick: bool = false # Tracks if we are rolling/flipping
var is_dead: bool = false # Tracks if we crashed
var is_spawning: bool = false # NEW: Tracks if we are in the intro cinematic!

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pivot.set_as_top_level(true) 
	spring_arm.set_as_top_level(true)
	
	ScoreManager.prepare_for_restart()
	
	# Start the intro sequence!
	play_portal_intro()

func _input(event):
	if is_spawning: return # LOCK INPUT DURING SPAWN
	
	# Locked mouse input while a trick is happening!
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not is_doing_trick:
		if event is InputEventMouseMotion:
			cam_yaw -= event.relative.x * mouse_sensitivity
			cam_pitch -= event.relative.y * mouse_sensitivity

func _physics_process(delta: float) -> void:
	if is_spawning: return # LOCK MOVEMENT DURING SPAWN
	
	if Input.is_action_just_pressed("pause"):
		get_tree().change_scene_to_file("res://pause_menu.tscn")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
		
	# Check for the Barrel Roll!
	if Input.is_physical_key_pressed(KEY_E) and not is_doing_trick:
		do_barrel_roll()
		
	# Check for the U-Turn!
	if Input.is_physical_key_pressed(KEY_Q) and not is_doing_trick:
		do_u_turn()

	# 1. SMOOTH CAMERA TURN: Uses the plane's actual tilt angle
	# Locked out while a trick is happening!
	if not is_doing_trick:
		var turn_ratio = current_roll_angle / max_roll_angle
		cam_yaw += turn_ratio * bank_turn_speed * delta 
	
	# 2. Force the nose down into a dive if stalled
	if current_speed < min_speed:
		var stall_ratio = 1.0 - (current_speed / min_speed)
		cam_pitch -= stall_ratio * stall_nose_down_speed * delta

	pivot.global_position = global_position
	pivot.rotation = Vector3(cam_pitch, cam_yaw, 0)

	handle_flight_rotation(delta)
	calculate_flight_speed(delta)
	update_flight_animations()
	move_and_slide()
	
	if get_slide_collision_count() > 0:
		crash_sequence()
		return 

	if proximity_cast:
		proximity_cast.force_shapecast_update()
		if proximity_cast.is_colliding():
			var closeness = 1.0 - proximity_cast.get_closest_collision_safe_fraction()
			ScoreManager.add_proximity_points(delta, closeness)
		else:
			ScoreManager.stop_scoring()

	update_camera_effects(delta)
	update_camera_soft_follow(delta) 
	
	# --- VELOCITY & GRAVITY LOGIC ---
	var forward_dir = -global_transform.basis.z
	var engine_velocity = forward_dir * current_speed
	
	var stall_gravity = 0.0
	if current_speed < min_speed:
		var stall_ratio = 1.0 - (current_speed / min_speed)
		stall_gravity = max_stall_gravity * stall_ratio
		
	var target_velocity = engine_velocity + (Vector3.DOWN * stall_gravity)
	
	var speed_ratio = clamp((current_speed - min_speed) / (max_speed - min_speed), 0.0, 1.0)
	var current_grip = lerp(8.0, 4.0, speed_ratio)
	
	velocity = velocity.lerp(target_velocity, current_grip * delta) 

func play_portal_intro():
	is_spawning = true
	set_physics_process(false) # FREEZE the player during loading and intro
	if mesh_container: mesh_container.hide()
	if anim_player:
		anim_player.play("idle fly")
	var root = get_tree().root
	var cinematic_cam = root.find_child("CinematicCam", true, false)
	if cinematic_cam:
		cinematic_cam.make_current()
		
	# === THE FIX: FIND PORTAL AND HIDE IT IMMEDIATELY ===
	print("--- SEARCHING FOR PORTAL NODES ---")
	var portal_node = root.find_child("SpawnPortal", true, false)
	var portal_graphic = root.find_child("PortalGraphic", true, false)
	
	if portal_graphic:
		# Crush it down so it's invisible WHILE the loading screen is still up
		portal_graphic.scale = Vector3(0.01, 0.0, 1.0) 
		
	print("Waiting for loading screen to finish...")
	# === DYNAMIC LOADING WAIT ===
	var loading_screen = root.find_child("LoadingScreen", true, false)
	if loading_screen:
		while is_instance_valid(loading_screen) and loading_screen.visible:
			await get_tree().process_frame
	
	if portal_node and portal_graphic and cinematic_cam:
		print("SUCCESS! Starting slash animation.")
		cinematic_cam.make_current()
		
		# Wait a tiny bit for the scene to settle
		await get_tree().create_timer(0.2).timeout
		
		# 2. DRAW THE SLASH (Animate Y scale from 0 to 4)
		var slice_tween = create_tween()
		slice_tween.tween_property(portal_graphic, "scale", Vector3(0.01, 4.0, 1.0), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await slice_tween.finished
		
		# Pause for effect so the player sees the thin line
		await get_tree().create_timer(0.2).timeout
		
		# 3. POP IT OPEN (Animate X scale to 4)
		var open_tween = create_tween()
		open_tween.tween_property(portal_graphic, "scale", Vector3(3.0, 4.0, 4.0), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await open_tween.finished
		
		# 4. Teleport player to it and show them
		global_position = portal_node.global_position
		global_rotation = portal_node.global_rotation
		if mesh_container: mesh_container.show()
		
		# 5. SPEW THE PLAYER OUT
		current_speed = max_speed 
		await get_tree().create_timer(0.2).timeout
		
		# 6. Shrink the portal away
		var close_tween = create_tween()
		close_tween.tween_property(portal_graphic, "scale", Vector3(0.0, 0.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE)
	else:
		print("WARNING: Could not find portal nodes! Using fallback spawn.")
		var spawn_point = root.find_child("Spawn", true, false)
		if spawn_point:
			global_position = spawn_point.global_position
			global_rotation = spawn_point.global_rotation
		if mesh_container: mesh_container.show()
		
	# 7. Give control back to the player!
	print("Switching back to player camera.")
	cam_yaw = global_rotation.y
	cam_pitch = global_rotation.x
	camera.make_current() # Switch back to player camera
	is_spawning = false
	set_physics_process(true) # UNFREEZE the player so they can fly
	ScoreManager.start_flying()
func handle_flight_rotation(delta):
	var roll_input = Input.get_axis("right", "left")        
	var pitch_input = -Input.get_axis("forward", "back") 
	
	# Banking logic (WASD)
	current_roll_angle = lerp_angle(current_roll_angle, roll_input * max_roll_angle, roll_tilt_speed * delta)
	current_pitch_angle = lerp_angle(current_pitch_angle, pitch_input * max_pitch_angle, pitch_tilt_speed * delta)
		
	var target_z = -pivot.global_transform.basis.z
	var reference_up = pivot.global_transform.basis.y 
	
	var right = target_z.cross(reference_up).normalized()
	var up = right.cross(target_z).normalized()
	
	var target_basis = Basis(right, up, -target_z).orthonormalized()
	
	target_basis = target_basis.rotated(target_basis.x, current_pitch_angle)
	target_basis = target_basis.rotated(target_basis.z, -current_roll_angle)
	
	global_transform.basis = global_transform.basis.orthonormalized()
	var current_quat = global_transform.basis.get_rotation_quaternion()
	var target_quat = target_basis.get_rotation_quaternion()
	
	global_transform.basis = Basis(current_quat.slerp(target_quat, body_turn_speed * delta))
		
	if mesh_container:
		if not is_doing_trick:
			var visual_tilt = -roll_input * deg_to_rad(30)
			mesh_container.rotation.z = lerp_angle(mesh_container.rotation.z, visual_tilt, delta * 5.0) 

func calculate_flight_speed(delta):
	var look_dir_y = -global_transform.basis.z.y 
	
	if look_dir_y < 0: 
		current_speed += abs(look_dir_y) * dive_acceleration * delta
	else: 
		current_speed -= look_dir_y * up_deceleration * delta
	
	if current_speed < min_speed:
		current_speed += 8.0 * delta 
	elif current_speed > min_speed and look_dir_y >= 0:
		current_speed -= 2.0 * delta 
		
	current_speed = clamp(current_speed, 0.0, max_speed)

func update_camera_soft_follow(delta: float):
	var back_dir = pivot.global_transform.basis.z
	var up_dir = pivot.global_transform.basis.y
	var target_pos = global_position + (back_dir * 1.0) + (up_dir * 1.0)
	
	spring_arm.global_position = spring_arm.global_position.lerp(target_pos, delta * 15.0)
	
	var target_quat = pivot.global_transform.basis.get_rotation_quaternion()
	var current_quat = spring_arm.global_transform.basis.get_rotation_quaternion()
	spring_arm.global_transform.basis = Basis(current_quat.slerp(target_quat, delta * 15.0))
	
	# === THE FIX ===
	# Use the smoothed roll angle instead of raw keyboard input!
	var smoothed_roll_ratio = current_roll_angle / max_roll_angle
	var target_cam_pos = Vector3(-smoothed_roll_ratio * cam_offset_amount, 0, 0)
	camera.transform.origin = camera.transform.origin.lerp(target_cam_pos, delta * cam_offset_speed)

func update_camera_effects(delta): 
	var target_fov = 75.0 + (current_speed * 0.7) 
	camera.fov = lerp(camera.fov, target_fov, delta * 2.0)  
	
	# === THE FIX ===
	# Use the smoothed roll angle here as well!
	var smoothed_roll_ratio = current_roll_angle / max_roll_angle
	var target_tilt = smoothed_roll_ratio * deg_to_rad(15.0) 
	camera.rotation.z = lerp_angle(camera.rotation.z, target_tilt, delta * 5.0)
	
	if not wind_particles.emitting:
		wind_particles.emitting = true
	
	var _speed_ratio = clamp((current_speed - min_speed) / (max_speed - min_speed), 0.1, 1.0)
	if abs(wind_particles.amount_ratio - _speed_ratio) > 0.05:
		wind_particles.amount_ratio = _speed_ratio

func crash_sequence():
	if is_dead: return
	is_dead = true
	
	# 1. Stop processing movement and camera updates
	set_physics_process(false)
	set_process(false)
	
	# 2. Stop scoring
	ScoreManager.stop_flying()
	ScoreManager.crash() 
	
	# 3. Hide the player model and disable wind particles
	if mesh_container:
		mesh_container.hide()
	if wind_particles:
		wind_particles.emitting = false
		
	# === PLAY THE SOUND ===
	if crash_sound:
		crash_sound.play()
	# ======================
		
	# Wait for 2 seconds while the camera stays locked
	await get_tree().create_timer(2.0).timeout
	
	# 4. Bring up the UI!
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var game_over_menu = GAME_OVER_SCREEN.instantiate()
	get_tree().current_scene.add_child(game_over_menu)
	game_over_menu.set_final_score(ScoreManager.total_score)

func do_barrel_roll():
	is_doing_trick = true
	
	# Give 50 points and +0.5 to multiplier!
	ScoreManager.add_trick_points("BARREL ROLL", 50, 0.5) 
	
	if anim_player:
		# I see you have a left and right roll! You can change this to "barrel roll right" if you prefer
		anim_player.play("barrel roll left") 
		
		# Wait for the animation to finish playing completely
		await anim_player.animation_finished
	else:
		# Fallback just in case the animation player is missing
		await get_tree().create_timer(0.6).timeout
		
	is_doing_trick = false
	
	if anim_player:
		# Go back to flying smoothly!
		anim_player.play("idle fly", 0.3)
func do_u_turn():
	if not mesh_container: return
	is_doing_trick = true
	
	# Give 100 points and +1.0 to multiplier!
	ScoreManager.add_trick_points("U-TURN", 100, 1.0) 
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "cam_yaw", cam_yaw + PI, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if mesh_container:
		var start_rot = mesh_container.rotation.z
		tween.tween_property(mesh_container, "rotation:z", start_rot + TAU, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	if mesh_container: mesh_container.rotation.z = wrapf(mesh_container.rotation.z, -PI, PI)
	cam_yaw = wrapf(cam_yaw, -PI, PI)
	is_doing_trick = false

func update_flight_animations():
	# Don't interrupt if we are dead, spawning, or in the middle of a barrel roll!
	if is_spawning or is_doing_trick or is_dead: 
		return
		
	var target_anim = "idle fly" # <-- DEFAULT FLYING ANIMATION (Update if needed!)
	
	if Input.is_physical_key_pressed(KEY_A) and not Input.is_physical_key_pressed(KEY_D):
		target_anim = "lean left" # <-- REPLACE WITH YOUR LEAN LEFT ANIMATION!
	elif Input.is_physical_key_pressed(KEY_D) and not Input.is_physical_key_pressed(KEY_A):
		target_anim = "lean right" # <-- REPLACE WITH YOUR LEAN RIGHT ANIMATION!
		
	# Only tell it to play if it's not ALREADY playing that exact animation
	# (This prevents the animation from restarting on frame 0 every single millisecond)
	if anim_player and anim_player.current_animation != target_anim:
		anim_player.play(target_anim, 0.6)
