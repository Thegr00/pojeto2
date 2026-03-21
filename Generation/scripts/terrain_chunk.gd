class_name TerrainChunk
extends Node3D

var is_in_use := false
var pending_recycle := false
var task_id: int = -1
var builder: ChunkBuilder

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
	position = Vector3(pos) * (ChunkBuilder.CHUNK_SIZE * ChunkBuilder.VOXEL_SIZE)
	
	builder = ChunkBuilder.new()
	builder.chunk_pos = pos
	builder.flight_path = flight_path
	builder.noise_data = shared_noise 
	
	task_id = WorkerThreadPool.add_task(builder.execute_job, true)
	# IMPORTANT: We only check once per frame to avoid choking the main thread
	set_process(true)

func _process(_delta: float) -> void:
	if task_id != -1 and WorkerThreadPool.is_task_completed(task_id):
		WorkerThreadPool.wait_for_task_completion(task_id) 
		task_id = -1
		
		if pending_recycle:
			_finish_recycle()
		else:
			# FIX: Defer the application to the end of the frame so it doesn't interrupt rendering
			call_deferred("_apply_generated_data")
			set_process(false)

func _apply_generated_data() -> void:
	if builder.is_empty or builder.out_vertices.is_empty() or builder.out_indices.is_empty():
		hide()
		return
		
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = builder.out_vertices
	arrays[Mesh.ARRAY_NORMAL] = builder.out_normals
	arrays[Mesh.ARRAY_INDEX] = builder.out_indices
	# Added colors back in so your checkerboard works!
	arrays[Mesh.ARRAY_COLOR] = builder.out_colors 
	
	var new_mesh = ArrayMesh.new()
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = new_mesh
	
	if builder.out_collision_faces.size() > 0:
		var new_shape = ConcavePolygonShape3D.new()
		new_shape.set_faces(builder.out_collision_faces)
		collision_shape.shape = new_shape
	
	show()

func recycle() -> void:
	if not is_in_use:
		return
	pending_recycle = true
	hide()
	if task_id == -1:
		_finish_recycle()

func _finish_recycle() -> void:
	is_in_use = false
	pending_recycle = false
	mesh_instance.mesh = null
	collision_shape.shape = null
	set_process(false)
