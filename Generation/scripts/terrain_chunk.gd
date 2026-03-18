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

func begin_generation(pos: Vector3i, flight_path: FlightPath, world_seed: int) -> void:
	is_in_use = true
	pending_recycle = false
	position = Vector3(pos) * (ChunkBuilder.CHUNK_SIZE * ChunkBuilder.VOXEL_SIZE)
	
	var local_noise = TerrainNoise.new()
	local_noise.setup(world_seed)
	
	builder = ChunkBuilder.new()
	builder.chunk_pos = pos
	builder.flight_path = flight_path
	builder.noise_data = local_noise
	
	task_id = WorkerThreadPool.add_task(builder.execute_job, true)
	set_process(true)

func _process(_delta: float) -> void:
	# Check if the thread is done
	if task_id != -1 and WorkerThreadPool.is_task_completed(task_id):
		WorkerThreadPool.wait_for_task_completion(task_id) # Safe to call now, it's already done
		task_id = -1
		
		# If the player moved away while it was building, scrap it
		if pending_recycle:
			_finish_recycle()
		else:
			_apply_generated_data()
			set_process(false)

func _apply_generated_data() -> void:
	# Crash protection: Check if the chunk is completely empty or has no faces
	if builder.is_empty or builder.out_vertices.is_empty() or builder.out_indices.is_empty():
		hide()
		return
		
	# Safely build the Mesh on the main thread
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = builder.out_vertices
	arrays[Mesh.ARRAY_NORMAL] = builder.out_normals
	arrays[Mesh.ARRAY_INDEX] = builder.out_indices
	
	var new_mesh = ArrayMesh.new()
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = new_mesh
	
	# Safely build the Collision on the main thread
	var faces = PackedVector3Array()
	faces.resize(builder.out_indices.size())
	for i in range(builder.out_indices.size()):
		faces[i] = builder.out_vertices[builder.out_indices[i]]
		
	var new_shape = ConcavePolygonShape3D.new()
	new_shape.set_faces(faces)
	collision_shape.shape = new_shape
	
	show()
func recycle() -> void:
	if not is_in_use:
		return
		
	# Mark it to be recycled, but DO NOT block the main thread waiting for it!
	pending_recycle = true
	hide()
	
	# If no thread is running, we can recycle it instantlysdaw
	if task_id == -1:
		_finish_recycle()

func _finish_recycle() -> void:
	is_in_use = false
	pending_recycle = false
	mesh_instance.mesh = null
	collision_shape.shape = null
	set_process(false)
