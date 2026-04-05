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

@onready var wind_particles = $"cam origin/AshSnowFall"
@export var mesh_container: Node3D
@onready var proximity_cast: ShapeCast3D = $ShapeCast3D

var current_speed = 10.0
var cam_yaw: float = 0.0
var cam_pitch: float = 0.0
var current_roll_angle: float = 0.0
var current_pitch_angle: float = 0.0
var is_doing_trick: bool = false # Tracks if we are rolling/flipping

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	pivot.set_as_top_level(true) 
	spring_arm.set_as_top_level(true) 
	
	cam_yaw = global_rotation.y
	cam_pitch = global_rotation.x
	
	ScoreManager.prepare_for_restart()
	ScoreManager.start_flying()

func _input(event):
	# Locked mouse input while a trick is happening!
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not is_doing_trick:
		if event is InputEventMouseMotion:
			cam_yaw -= event.relative.x * mouse_sensitivity
			cam_pitch -= event.relative.y * mouse_sensitivity

func _physics_process(delta: float) -> void:
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
	
	var roll_input = Input.get_axis("right", "left")
	var target_cam_pos = Vector3(-roll_input * cam_offset_amount, 0, 0)
	camera.transform.origin = camera.transform.origin.lerp(target_cam_pos, delta * cam_offset_speed)

func update_camera_effects(delta): 
	var target_fov = 75.0 + (current_speed * 0.7) 
	camera.fov = lerp(camera.fov, target_fov, delta * 2.0)  
	
	var roll_input = Input.get_axis("right", "left")
	var target_tilt = roll_input * deg_to_rad(15.0) 
	camera.rotation.z = lerp_angle(camera.rotation.z, target_tilt, delta * 5.0)
	
	if not wind_particles.emitting:
		wind_particles.emitting = true
	
	var _speed_ratio = clamp((current_speed - min_speed) / (max_speed - min_speed), 0.1, 1.0)
	if abs(wind_particles.amount_ratio - _speed_ratio) > 0.05:
		wind_particles.amount_ratio = _speed_ratio

func crash_sequence():
	ScoreManager.stop_flying()
	ScoreManager.crash() 
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var game_over_menu = GAME_OVER_SCREEN.instantiate()
	get_tree().current_scene.add_child(game_over_menu)
	game_over_menu.set_final_score(ScoreManager.total_score)
	get_tree().paused = true
	set_physics_process(false)

func do_barrel_roll():
	if not mesh_container: return
	is_doing_trick = true
	
	# Give 50 points and +0.5 to multiplier!
	ScoreManager.add_trick_points("BARREL ROLL", 50, 0.5) 
	
	var tween = create_tween()
	var start_rot = mesh_container.rotation.z
	tween.tween_property(mesh_container, "rotation:z", start_rot + TAU, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	if mesh_container: mesh_container.rotation.z = wrapf(mesh_container.rotation.z, -PI, PI)
	is_doing_trick = false

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
