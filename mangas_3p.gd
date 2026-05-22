extends CharacterBody3D

const DEATH_SCENE = preload("res://death_scene.tscn")
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
@onready var wind_sound: AudioStreamPlayer = $WindSound # NEW: Added Wind Sound node reference
@export var mesh_container: Node3D
@onready var proximity_cast: ShapeCast3D = $ShapeCast3D
@onready var crash_sound: AudioStreamPlayer = $CrashSound

@export var is_cutscene: bool = false
var current_speed = 10.0
var cam_yaw: float = 0.0
var cam_pitch: float = 0.0
var current_roll_angle: float = 0.0
var current_pitch_angle: float = 0.0
var is_doing_trick: bool = false 
var is_dead: bool = false 
var is_spawning: bool = false 
var is_in_wind: bool = false
var current_wind_speed: float = 0.0
var wind_tween: Tween

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pivot.set_as_top_level(true) 
	spring_arm.set_as_top_level(true)
	
	ScoreManager.prepare_for_restart()

func _input(event):
	if is_spawning: return # LOCK INPUT DURING SPAWN
	
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
		
	if Input.is_physical_key_pressed(KEY_E) and not is_doing_trick:
		do_barrel_roll()
		
	if Input.is_physical_key_pressed(KEY_Q) and not is_doing_trick:
		do_u_turn()
	if is_in_wind:
		velocity.y = current_wind_speed
	else:
		# Otherwise, apply normal gravity when they aren't in the wind
		if not is_on_floor():
			velocity.y -= 9.8 * delta
	if not is_doing_trick:
		var turn_ratio = current_roll_angle / max_roll_angle
		cam_yaw += turn_ratio * bank_turn_speed * delta 
	
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

func handle_flight_rotation(delta):
	var roll_input = Input.get_axis("right", "left")        
	var pitch_input = -Input.get_axis("forward", "back") 
	
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
	var target_pos = global_position + (back_dir * 1.0) + (up_dir * 1.5)
	
	spring_arm.global_position = spring_arm.global_position.lerp(target_pos, delta * 20.0)
	
	var target_quat = pivot.global_transform.basis.get_rotation_quaternion()
	var current_quat = spring_arm.global_transform.basis.get_rotation_quaternion()
	spring_arm.global_transform.basis = Basis(current_quat.slerp(target_quat, delta * 15.0))
	
	var smoothed_roll_ratio = current_roll_angle / max_roll_angle
	var target_cam_pos = Vector3(-smoothed_roll_ratio * cam_offset_amount, 0, 0)
	camera.transform.origin = camera.transform.origin.lerp(target_cam_pos, delta * cam_offset_speed)

func update_camera_effects(delta): 
	var target_fov = 75.0 + (current_speed * 0.7) 
	camera.fov = lerp(camera.fov, target_fov, delta * 2.0)  
	
	var smoothed_roll_ratio = current_roll_angle / max_roll_angle
	var target_tilt = smoothed_roll_ratio * deg_to_rad(15.0) 
	camera.rotation.z = lerp_angle(camera.rotation.z, target_tilt, delta * 5.0)
	
	# === NEW WIND LOGIC WITH 60% MAX SPEED THRESHOLD ===
	var speed_threshold = max_speed * 0.3
	
	if current_speed >= speed_threshold:
		# 1. Turn on particles
		if not wind_particles.emitting:
			wind_particles.emitting = true
			
		# 2. Play the sound
		if wind_sound and not wind_sound.playing:
			wind_sound.play()
			
		# 3. Increase particle amount the faster you go above the threshold!
		var _speed_ratio = clamp((current_speed - speed_threshold) / (max_speed - speed_threshold), 0.1, 1.0)
		if abs(wind_particles.amount_ratio - _speed_ratio) > 0.05:
			wind_particles.amount_ratio = _speed_ratio
			
	else:
		# Turn off everything if we drop below 60% max speed
		if wind_particles.emitting:
			wind_particles.emitting = false
			
		if wind_sound and wind_sound.playing:
			wind_sound.stop()
	# ===================================================

func crash_sequence():
	if is_dead: return
	is_dead = true
	
	set_physics_process(false)
	set_process(false)
	
	ScoreManager.stop_flying()
	ScoreManager.crash() 
	
	if mesh_container:
		mesh_container.hide()
		
	# NEW: Stop wind and sound immediately upon crashing!
	if wind_particles:
		wind_particles.emitting = false
	if wind_sound and wind_sound.playing:
		wind_sound.stop()
		
	if crash_sound:
		crash_sound.play()
		
	
	await get_tree().create_timer(1.0).timeout
	
	var death_scene = DEATH_SCENE.instantiate()
	get_tree().current_scene.add_child(death_scene)
	
	await get_tree().create_timer(2.0).timeout
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var game_over_menu = GAME_OVER_SCREEN.instantiate()
	get_tree().current_scene.add_child(game_over_menu)
	game_over_menu.set_final_score(ScoreManager.total_score)

func do_barrel_roll():
	is_doing_trick = true
	ScoreManager.add_trick_points("BARREL ROLL", 50, 0.5) 
	
	if anim_player:
		anim_player.play("barrel roll left") 
		await anim_player.animation_finished
	else:
		await get_tree().create_timer(0.6).timeout
		
	is_doing_trick = false
	
	if anim_player:
		anim_player.play("idle fly", 0.3)

func do_u_turn():
	if not mesh_container: return
	is_doing_trick = true
	
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
	if is_spawning or is_doing_trick or is_dead: 
		return
		
	var target_anim = "idle fly" 
	
	if Input.is_physical_key_pressed(KEY_A) and not Input.is_physical_key_pressed(KEY_D):
		target_anim = "lean left" 
	elif Input.is_physical_key_pressed(KEY_D) and not Input.is_physical_key_pressed(KEY_A):
		target_anim = "lean right" 
		
	if anim_player and anim_player.current_animation != target_anim:
		anim_player.play(target_anim, 0.6)

# ==================================================
# NEW: PORTAL SPAWN HOOKS FOR THE CUTSCENE DIRECTOR
# ==================================================
func prepare_for_spawn():
	is_spawning = true
	set_physics_process(false) # FREEZE
	if mesh_container: mesh_container.hide()
	if anim_player: anim_player.play("idle fly")

func spew_out(spawn_transform: Transform3D):
	# Safely extract ONLY position and rotation
	global_position = spawn_transform.origin
	global_rotation = spawn_transform.basis.get_euler()
	
	# === NEW: Instantly snap the camera rig to the portal ===
	pivot.global_position = global_position
	pivot.rotation = Vector3(global_rotation.x, global_rotation.y, 0)
	spring_arm.global_position = global_position + (-pivot.global_transform.basis.z * 1.0) + (pivot.global_transform.basis.y * 1.0)
	spring_arm.global_transform.basis = pivot.global_transform.basis
	# =========================================================
	
	if mesh_container: 
		mesh_container.show()
		
	current_speed = max_speed

func finish_spawn():
	cam_yaw = global_rotation.y
	cam_pitch = global_rotation.x
	camera.make_current() # Switch back to player camera
	is_spawning = false
	set_physics_process(true) # UNFREEZE
	ScoreManager.start_flying()

func enter_wind(speed: float) -> void:
	# If the player jumps BACK into the wind while the fade-out is happening, 
	# we need to cancel the fade-out!
	if wind_tween:
		wind_tween.kill() 
		
	is_in_wind = true
	current_wind_speed = speed

func exit_wind() -> void:
	if wind_tween:
		wind_tween.kill()
		
	# Create a new animation tween
	wind_tween = create_tween()
	
	# This tells Godot: "Change 'current_wind_speed' to 0.0, over exactly 1.0 second."
	wind_tween.tween_property(self, "current_wind_speed", 0.0, 1.0)
	
	# Wait for that 1-second fade to finish
	await wind_tween.finished
	
	# Now that the speed has smoothly hit 0, we finally let normal gravity take over
	is_in_wind = false
