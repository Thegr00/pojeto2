class_name FlightPath
extends RefCounted

var points: Array[Vector3] = []

const PATH_LENGTH := 200
const STEP_DISTANCE := 45.0
const DROP_PER_STEP := 14.0

func generate(seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	points.clear()

	var current := Vector3.ZERO
	for i in PATH_LENGTH:
		points.append(current)
		var turn: float = rng.randf_range(-0.5, 0.5)
		current.x += sin(i * 0.4 + turn) * STEP_DISTANCE
		current.z += STEP_DISTANCE
		current.y -= DROP_PER_STEP

# Returns an array of segment dictionaries: { "start": Vector3, "end": Vector3 }
func get_local_segments(chunk_center: Vector3, radius: float) -> Array:
	var local_segments = []
	var radius_sq = radius * radius
	
	for i in range(points.size() - 1):
		var p1 = points[i]
		var p2 = points[i+1]
		
		# Simple bounding check: if either point of the segment is near the chunk
		if p1.distance_squared_to(chunk_center) < radius_sq or p2.distance_squared_to(chunk_center) < radius_sq:
			local_segments.append({"start": p1, "end": p2})
			
	return local_segments

# Calculates the shortest distance to a 3D line segment
func get_distance_to_segments(pos: Vector3, segments: Array) -> float:
	if segments.is_empty():
		return 9999.0
		
	var min_dist := 9999.0
	
	for seg in segments:
		var p1 = seg.start
		var p2 = seg.end
		
		var line_vec = p2 - p1
		var point_vec = pos - p1
		
		var line_len_sq = line_vec.length_squared()
		var t = max(0.0, min(1.0, point_vec.dot(line_vec) / line_len_sq))
		var projection = p1 + line_vec * t
		
		var d = pos.distance_to(projection)
		if d < min_dist:
			min_dist = d
			
	return min_dist
