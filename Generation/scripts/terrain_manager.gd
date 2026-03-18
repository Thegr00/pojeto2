class_name WorldManager
extends Node3D

@export var player: Node3D
const VIEW_DISTANCE = 4
const POOL_SIZE = 100 # Pre-allocate enough chunks to cover the view distance
const CHUNKS_PER_FRAME = 2

var world_seed = randi()
var active_chunks: Dictionary = {}
var chunk_queue: Array[Vector3i] = []
var chunk_pool: Array[TerrainChunk] = []
var last_player_chunk := Vector3i(999999, 999999, 999999)
var flight_path: FlightPath

func _ready() -> void:
	flight_path = FlightPath.new()
	flight_path.generate(world_seed)
	
	# Initialize the object pool
	for i in range(POOL_SIZE):
		var chunk = TerrainChunk.new()
		add_child(chunk)
		chunk.hide()
		chunk_pool.append(chunk)

func _process(_delta: float) -> void:
	if player == null: 
		return
		
	var player_chunk = world_to_chunk(player.global_position)
	
	# ONLY run the heavy queueing and cleanup if we crossed into a new chunk!
	if player_chunk != last_player_chunk:
		_queue_needed_chunks(player_chunk)
		_cleanup_far_chunks(player_chunk)
		last_player_chunk = player_chunk
		
	# Keep dispatching a few chunks every frame smoothly
	_dispatch_queued_chunks()

func world_to_chunk(pos: Vector3) -> Vector3i:
	var actual_size = ChunkBuilder.CHUNK_SIZE * ChunkBuilder.VOXEL_SIZE 
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
						
	# Sort by distance to player so close chunks generate first
	chunk_queue.sort_custom(func(a, b): return a.distance_squared_to(center) < b.distance_squared_to(center))

func _dispatch_queued_chunks() -> void:
	var dispatched = 0
	while dispatched < CHUNKS_PER_FRAME and not chunk_queue.is_empty():
		# Find an available chunk in the pool
		var available_chunk = _get_free_chunk()
		if available_chunk == null:
			break # Pool is empty, wait for next frame
			
		var pos = chunk_queue.pop_front()
		active_chunks[pos] = available_chunk
		
		# PASS THE SEED, not the noise object, so the thread can build its own!
		available_chunk.begin_generation(pos, flight_path, world_seed)
		dispatched += 1

func _cleanup_far_chunks(center: Vector3i) -> void:
	var view_sq = (VIEW_DISTANCE + 1) * (VIEW_DISTANCE + 1)
	var keys_to_remove = []
	
	for chunk_pos in active_chunks.keys():
		if chunk_pos.distance_squared_to(center) > view_sq:
			var chunk = active_chunks[chunk_pos]
			chunk.recycle() # Hide and free up for the pool
			keys_to_remove.append(chunk_pos)
			
	for k in keys_to_remove:
		active_chunks.erase(k)
		
	# NEW: The missing queue cleanup!
	# Loop backwards so we can safely delete from the array
	var i = chunk_queue.size() - 1
	while i >= 0:
		if chunk_queue[i].distance_squared_to(center) > view_sq:
			chunk_queue.remove_at(i)
		i -= 1
func _get_free_chunk() -> TerrainChunk:
	for chunk in chunk_pool:
		if not chunk.is_in_use:
			return chunk
	return null
	
