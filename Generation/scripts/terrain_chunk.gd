class_name TerrainChunk
extends Node3D

var is_in_use := false
var pending_recycle := false

var is_waiting_to_mesh := false
var is_waiting_to_collide := false 

var task_id: int = -1
var builder: Variant = preload("res://Generation/scripts/ChunkBuilder.cs").new()

var mesh_instance: MeshInstance3D
var collision_shape: CollisionShape3D
var static_body: StaticBody3D

func _init() -> void:
	mesh_instance = MeshInstance3D.new()
	static_body = StaticBody3D.new()
	collision_shape = CollisionShape3D.new()

func _enter_tree() -> void:
	add_child(mesh_instance)
	add_child(static_body)
	static_body.add_child(collision_shape)

func begin_generation(pos: Vector3i, flight_path: FlightPath, shared_noise: TerrainNoise) -> void:
	is_in_use = true
	pending_recycle = false
	is_waiting_to_mesh = false
	is_waiting_to_collide = false
	
	# Since C# handles the constants, we just hardcode the chunk size (32 * 2.0) here for position
	position = Vector3(pos) * (64.0)
	
	builder = preload("res://Generation/scripts/ChunkBuilder.cs").new()
	builder.chunk_pos = pos
	builder.flight_path = flight_path
	builder.noise_data = shared_noise 
	
	task_id = WorkerThreadPool.add_task(builder.execute_job, true)
	set_process(true)

func _process(_delta: float) -> void:
	# 1. Did the background math finish?
	if task_id != -1 and WorkerThreadPool.is_task_completed(task_id):
		WorkerThreadPool.wait_for_task_completion(task_id) 
		task_id = -1
		
		if pending_recycle:
			_finish_recycle()
		else:
			is_waiting_to_mesh = true

	var wm = get_parent()
	
	# 2. Build visuals fast (We allow up to 3 meshes to build per frame)
	if is_waiting_to_mesh and wm.meshes_built_this_frame < 3:
		wm.meshes_built_this_frame += 1
		_apply_mesh_only()
		is_waiting_to_mesh = false
		is_waiting_to_collide = true # Move it to the collision waiting line
		
	# 3. Build physics slow (STRICT LIMIT: Only 1 heavy collision builds per frame)
	if is_waiting_to_collide and wm.collisions_built_this_frame < 1:
		wm.collisions_built_this_frame += 1
		_apply_collision_only()
		is_waiting_to_collide = false
		set_process(false)

func _apply_mesh_only() -> void:
	if builder.is_empty or builder.out_vertices == null or builder.out_vertices.is_empty():
		hide()
		return
		
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = builder.out_vertices
	arrays[Mesh.ARRAY_NORMAL] = builder.out_normals
	arrays[Mesh.ARRAY_INDEX] = builder.out_indices
	arrays[Mesh.ARRAY_COLOR] = builder.out_colors
	
	var new_mesh = ArrayMesh.new()
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = new_mesh
	show()

func _apply_collision_only() -> void:
	if builder.out_collision_faces != null and builder.out_collision_faces.size() > 0:
		var new_shape = ConcavePolygonShape3D.new()
		new_shape.set_faces(builder.out_collision_faces)
		collision_shape.shape = new_shape

func recycle() -> void:
	if not is_in_use: return
	pending_recycle = true
	is_waiting_to_mesh = false
	is_waiting_to_collide = false
	hide()
	if task_id == -1:
		_finish_recycle()

func _finish_recycle() -> void:
	is_in_use = false
	pending_recycle = false
	mesh_instance.mesh = null
	collision_shape.shape = null
	set_process(false)
