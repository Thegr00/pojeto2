class_name WorldManager
extends Node3D

@export var player: Node3D
const VIEW_DISTANCE = 4
const CHUNKS_PER_FRAME = 3 

var world_seed = randi()
var active_chunks: Dictionary = {}
var chunk_queue: Array[Vector3i] = []
var chunk_pool: Array[TerrainChunk] = []
var last_player_chunk := Vector3i(999999, 999999, 999999)

var flight_path: FlightPath
var shared_noise: TerrainNoise

var meshes_built_this_frame := 0
var collisions_built_this_frame := 0

func _ready() -> void:
	flight_path = FlightPath.new()
	flight_path.generate(world_seed)
	
	shared_noise = TerrainNoise.new()
	shared_noise.setup(world_seed)

func _process(_delta: float) -> void:
	meshes_built_this_frame = 0 
	collisions_built_this_frame = 0
	
	if player == null: 
		return
		
	var player_chunk = world_to_chunk(player.global_position)
	
	if player_chunk != last_player_chunk:
		_queue_needed_chunks(player_chunk)
		_cleanup_far_chunks(player_chunk)
		last_player_chunk = player_chunk
		
	_dispatch_queued_chunks()

func world_to_chunk(pos: Vector3) -> Vector3i:
	# Actual size is Chunk Size (32) * Voxel Size (2.0)
	var actual_size = 64.0 
	return Vector3i(
		floor(pos.x / actual_size),
		floor(pos.y / actual_size),
		floor(pos.z / actual_size)
	)

func _queue_needed_chunks(center: Vector3i) -> void:
	var view_sq = VIEW_DISTANCE * VIEW_DISTANCE
	
	for x in range(-VIEW_DISTANCE, VIEW_DISTANCE + 1):
		for z in range(-VIEW_DISTANCE, VIEW_DISTANCE + 1):
			for y in range(-VIEW_DISTANCE + 1, VIEW_DISTANCE):
				var offset = Vector3i(x, y, z)
				if offset.length_squared() <= view_sq:
					var c = center + offset
					if not active_chunks.has(c) and c not in chunk_queue:
						chunk_queue.append(c)
						
	chunk_queue.sort_custom(func(a, b): return a.distance_squared_to(center) < b.distance_squared_to(center))

func _dispatch_queued_chunks() -> void:
	var dispatched = 0
	while dispatched < CHUNKS_PER_FRAME and not chunk_queue.is_empty():
		var available_chunk = _get_free_chunk()
		var pos = chunk_queue.pop_front()
		
		active_chunks[pos] = available_chunk
		available_chunk.begin_generation(pos, flight_path, shared_noise)
		
		dispatched += 1

func _get_free_chunk() -> TerrainChunk:
	# Look for an unused chunk
	for chunk in chunk_pool:
		if not chunk.is_in_use:
			return chunk
			
	# DYNAMIC POOL: If we run out, create exactly one instantly!
	var new_chunk = TerrainChunk.new()
	add_child(new_chunk)
	chunk_pool.append(new_chunk)
	return new_chunk

func _cleanup_far_chunks(center: Vector3i) -> void:
	var view_sq = (VIEW_DISTANCE + 1) * (VIEW_DISTANCE + 1)
	var keys_to_remove = []
	
	for chunk_pos in active_chunks.keys():
		if chunk_pos.distance_squared_to(center) > view_sq:
			var chunk = active_chunks[chunk_pos]
			chunk.recycle() 
			keys_to_remove.append(chunk_pos)
			
	for k in keys_to_remove:
		active_chunks.erase(k)
		
	var i = chunk_queue.size() - 1
	while i >= 0:
		if chunk_queue[i].distance_squared_to(center) > view_sq:
			chunk_queue.remove_at(i)
		i -= 1
