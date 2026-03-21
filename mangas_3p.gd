extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

const GAME_OVER_SCREEN = preload("res://game_over_screen.tscn") 

@export_group("Flight Constants")
@export var max_speed = 60.0
@export var min_speed = 15.0
@export var dive_acceleration = 30.0  
@export var up_deceleration = 15.0 
@export var rotation_speed = 3
@export var slerp_speed = 3.0

@export_group("Camera")
@onready var pivot = $"cam origin"
@onready var camera = $"cam origin/SpringArm3D/CABECA"
@onready var spring_arm = $"cam origin"/SpringArm3D
@export var sens = 0.5

@export var cam_offset_amount: float = 0.5  
@export var cam_offset_speed: float = 3.0

@onready var wind_particles = $"cam origin/Particulas"
@export var mesh_container: Node3D

@onready var proximity_cast: ShapeCast3D = $ShapeCast3D
const MAX_PROXIMITY_DISTANCE = 15.0 

var current_speed = 10.0

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spring_arm.set_as_top_level(true) 
	
	# Force a reset on spawn just in case
	ScoreManager.total_score = 0
	ScoreManager.unbanked_score = 0.0
	ScoreManager.current_multiplier = 1.0
	
	GameManager.start_flying()

func _input(_event):
	pass

func toggle_pause():
	var new_pause_state = not get_tree().paused
	get_tree().paused = new_pause_state
	visible = new_pause_state

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		get_tree().change_scene_to_file("res://pause_menu.tscn")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	handle_flight_rotation(delta)
	calculate_flight_speed(delta)
	
	move_and_slide()
	
	if proximity_cast:
		proximity_cast.force_shapecast_update()
		
		if proximity_cast.is_colliding():
			var fraction = proximity_cast.get_closest_collision_safe_fraction()
			var closeness = 1.0 - fraction 
			ScoreManager.add_proximity_points(delta, closeness)
		else:
			ScoreManager.stop_scoring()
	
	if get_slide_collision_count() > 0:
		GameManager.stop_flying()
		ScoreManager.crash() 
		
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
		var game_over_menu = GAME_OVER_SCREEN.instantiate()
		get_tree().current_scene.add_child(game_over_menu)
		game_over_menu.set_final_score(ScoreManager.total_score)
		
		get_tree().paused = true
		set_physics_process(false)
		return 

	update_camera_effects(delta)
	update_camera_soft_follow(delta) 
	
	var forward_dir = -global_transform.basis.z
	var target_velocity = forward_dir * current_speed
	velocity = velocity.lerp(target_velocity, slerp_speed * delta) 
	
	if current_speed < min_speed + 2: 
		velocity += get_gravity() * delta

func handle_flight_rotation(delta):
	var pitch = Input.get_axis("back", "forward")  
	var roll = Input.get_axis("left", "right")     
	if pitch != 0:
		transform.basis = transform.basis.rotated(transform.basis.x, pitch * rotation_speed * delta)
	if roll != 0:
		transform.basis = transform.basis.rotated(transform.basis.z, roll * rotation_speed * delta)
	var bank_amount = transform.basis.x.y 
	transform.basis = transform.basis.rotated(Vector3.UP, -bank_amount * delta * 3.0)
	if roll == 0:
		var target_up = Vector3.UP
		var look_dir = -transform.basis.z
		var right_dir = look_dir.cross(target_up).normalized()
		var actual_up = right_dir.cross(look_dir).normalized()
		var target_basis = Basis(right_dir, actual_up, -look_dir)
		transform.basis = transform.basis.slerp(target_basis, delta * 1.5)
		transform.basis = transform.basis.orthonormalized()
	if mesh_container:
		var target_tilt = -roll * deg_to_rad(20)
		mesh_container.rotation.z = lerp_angle(mesh_container.rotation.z, target_tilt, delta * 5.0)	

func calculate_flight_speed(delta):
	var look_dir_y = -transform.basis.z.y 
	if look_dir_y < 0: 
		current_speed += abs(look_dir_y)* dive_acceleration * delta
	else: 
		current_speed -= look_dir_y * up_deceleration * delta
	current_speed -= 1.0 * delta
	current_speed = clamp(current_speed, min_speed, max_speed)

func update_camera_soft_follow(delta: float):
	var _offset = (-global_transform.basis.z * -4.0) + (global_transform.basis.y * 1.0)
	var back_dir = global_transform.basis.z
	var up_dir = global_transform.basis.y
	var target_pos = global_position + (back_dir * 1.0) + (up_dir * 1.0)
	spring_arm.global_position = spring_arm.global_position.lerp(target_pos, delta * 8.0)
	var target_quat = global_transform.basis.get_rotation_quaternion()
	var current_quat = spring_arm.global_transform.basis.get_rotation_quaternion()
	spring_arm.global_transform.basis = Basis(current_quat.slerp(target_quat, delta * 6.0))
	var input_dir = Vector2(
		Input.get_axis("left", "right"), 
		Input.get_axis("forward", "back")
	)
	var target_cam_pos = Vector3(
		-input_dir.x * cam_offset_amount, 
		-input_dir.y * (cam_offset_amount * 0.5), 0
	)
	camera.transform.origin = camera.transform.origin.lerp(target_cam_pos, delta * cam_offset_speed)
	var target_margin = 0.2 + (current_speed * 0.00005) 
	spring_arm.spring_length = lerp(spring_arm.spring_length, target_margin, delta * 2.0)

func update_camera_effects(delta): 
	var target_fov = 75.0 + (current_speed * 0.7) 
	camera.fov = lerp(camera.fov, target_fov, delta * 2.0)  
	var subtle_tilt = -rotation.z * 0.2 
	camera.rotation.z = lerp_angle(camera.rotation.z, subtle_tilt, delta * 5.0)
	var _speed_ratio = (current_speed - min_speed) / (max_speed - min_speed) 
	if _speed_ratio > 0.8:
		wind_particles.emitting = true
		wind_particles.amount_ratio = clamp(_speed_ratio, 0.0, 1.0)
	else:
		wind_particles.emitting = false
