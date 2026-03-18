class_name ChunkBuilder
extends RefCounted

const CHUNK_SIZE = 32
const VOXEL_SIZE = 2.0
const ISO_LEVEL = 0.0

var chunk_pos: Vector3i
var flight_path
var noise_data: TerrainNoise

var generated_mesh: ArrayMesh
var generated_shape: ConcavePolygonShape3D
var is_empty := true
var out_vertices: PackedVector3Array
var out_normals: PackedVector3Array
var out_indices: PackedInt32Array

func execute_job() -> void:
	var chunk_center_world = (Vector3(chunk_pos) * CHUNK_SIZE * VOXEL_SIZE) + (Vector3.ONE * CHUNK_SIZE * VOXEL_SIZE * 0.5)
	var search_radius = (CHUNK_SIZE * VOXEL_SIZE) * 2.0
	
	# Optimized path fetching
	var local_segments = flight_path.get_local_segments(chunk_center_world, search_radius)
	
	var density_map = _generate_density_field(local_segments)
	
	if not is_empty:
		_build_mesh_and_collision(density_map)

func _generate_density_field(local_segments: Array) -> PackedFloat32Array:
	var total = (CHUNK_SIZE + 1) * (CHUNK_SIZE + 1) * (CHUNK_SIZE + 1)
	var map = PackedFloat32Array()
	map.resize(total)
	
	var idx = 0
	for z in range(CHUNK_SIZE + 1):
		for y in range(CHUNK_SIZE + 1):
			for x in range(CHUNK_SIZE + 1):
				var world_pos = (Vector3(x, y, z) + Vector3(chunk_pos * CHUNK_SIZE)) * VOXEL_SIZE
				var d = calculate_sdf(world_pos, local_segments)
				map[idx] = d
				
				if d > ISO_LEVEL:
					is_empty = false
				idx += 1
	return map

func calculate_sdf(pos: Vector3, local_segments: Array) -> float:
	# 1. The Floating Islands
	# We multiply the Y position by 0.3 when sampling the noise. 
	# This "squashes" the noise space, which stretches the physical rock vertically!
	var noise_val = noise_data.float_noise.get_noise_3d(pos.x, pos.y * 0.3, pos.z)
	
	# In SDF, Negative = Rock, Positive = Air.
	# We invert the noise and add an offset. 
	# (Increase the 0.15 to make thicker islands, decrease to make them thinner)
	var base_terrain = -noise_val + 0.15 
	
	# Multiply by 80.0 to scale the "hardness" of the SDF gradient
	base_terrain *= 80.0 
	
	# 2. The Dive Canyons
	# Find how close we are to the generated flight path
	var dist = flight_path.get_distance_to_segments(pos, local_segments)
	
	# Create a massive tube of air (radius 65.0) around the path so you don't spawn in a wall
	var canyon_air = 65.0 - dist
	
	# 3. Combine!
	# The max() function takes whichever is higher. 
	# If we are inside the canyon, canyon_air is positive, which overwrites the negative rock!
	var final_d = max(base_terrain, canyon_air)
	
	return final_d
# Helper to get the index for the (CHUNK_SIZE + 1) density array
func _get_idx(x: int, y: int, z: int) -> int:
	return x + (CHUNK_SIZE + 1) * (y + (CHUNK_SIZE + 1) * z)

# Helper to get the index for the (CHUNK_SIZE) voxel cell array
func _get_cell_idx(x: int, y: int, z: int) -> int:
	return x + CHUNK_SIZE * (y + CHUNK_SIZE * z)

func arch_density(pos: Vector3) -> float:
	var arch_center := Vector3(round(pos.x / 120.0) * 120.0, 40.0, round(pos.z / 120.0) * 120.0)
	var ring : float = abs(pos.distance_to(arch_center) - 30.0)
	return 8.0 - ring

func smin(a: float, b: float, k: float) -> float:
	var h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
	return lerp(b, a, h) - k * h * (1.0 - h)

func _build_mesh_and_collision(density_map: PackedFloat32Array) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	# Map to remember which vertex ID belongs to which voxel cell
	var cell_vertex_indices = PackedInt32Array()
	cell_vertex_indices.resize(CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE)
	cell_vertex_indices.fill(-1)

	var corner_offsets = [
		Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(1, 1, 0), Vector3i(0, 1, 0),
		Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(1, 1, 1), Vector3i(0, 1, 1)
	]
	var edge_pairs = [
		[0,1], [1,2], [2,3], [3,0], # Bottom edges
		[4,5], [5,6], [6,7], [7,4], # Top edges
		[0,4], [1,5], [2,6], [3,7]  # Vertical edges
	]

	# ==========================================
	# PASS 1: Find surface cells and place vertices
	# ==========================================
	var current_vertex_idx = 0
	for z in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			for x in range(CHUNK_SIZE):
				var corners = []
				var mask = 0

				# Check the 8 corners of the current cell
				for i in range(8):
					var offset = corner_offsets[i]
					var d = density_map[_get_idx(x + offset.x, y + offset.y, z + offset.z)]
					corners.append(d)
					if d < ISO_LEVEL:
						mask |= (1 << i)

				# If cell is entirely air (255) or entirely solid rock (0), skip it!
				if mask == 0 or mask == 255:
					continue

				# Find where the terrain cuts through the edges
				var edge_count = 0
				var vertex_pos = Vector3.ZERO

				for edge in edge_pairs:
					var d1 = corners[edge[0]]
					var d2 = corners[edge[1]]

					# If the edge crosses the ISO_LEVEL (surface)
					if (d1 < ISO_LEVEL) != (d2 < ISO_LEVEL):
						var t = (ISO_LEVEL - d1) / (d2 - d1)
						var p1 = Vector3(corner_offsets[edge[0]])
						var p2 = Vector3(corner_offsets[edge[1]])
						vertex_pos += p1.lerp(p2, t)
						edge_count += 1

				if edge_count > 0:
					vertex_pos /= float(edge_count) # Average the crossing points
					vertices.append((Vector3(x, y, z) + vertex_pos) * VOXEL_SIZE)
					normals.append(Vector3.ZERO) # Placeholder for Pass 3
					
					cell_vertex_indices[_get_cell_idx(x, y, z)] = current_vertex_idx
					current_vertex_idx += 1

	# ==========================================
	# PASS 2: Connect vertices into faces (Quads)
	# ==========================================
	for z in range(1, CHUNK_SIZE):
		for y in range(1, CHUNK_SIZE):
			for x in range(1, CHUNK_SIZE):
				var is_inside = density_map[_get_idx(x, y, z)] < ISO_LEVEL

				# Check X edge
				if is_inside != (density_map[_get_idx(x+1, y, z)] < ISO_LEVEL) and x < CHUNK_SIZE - 1:
					var v1 = cell_vertex_indices[_get_cell_idx(x, y, z)]
					var v2 = cell_vertex_indices[_get_cell_idx(x, y-1, z)]
					var v3 = cell_vertex_indices[_get_cell_idx(x, y-1, z-1)]
					var v4 = cell_vertex_indices[_get_cell_idx(x, y, z-1)]
					
					if v1 != -1 and v2 != -1 and v3 != -1 and v4 != -1:
						if is_inside: indices.append_array([v1, v2, v3, v1, v3, v4])
						else:         indices.append_array([v1, v4, v3, v1, v3, v2])
				
				# Check Y edge
				if is_inside != (density_map[_get_idx(x, y+1, z)] < ISO_LEVEL) and y < CHUNK_SIZE - 1:
					var v1 = cell_vertex_indices[_get_cell_idx(x, y, z)]
					var v2 = cell_vertex_indices[_get_cell_idx(x, y, z-1)]
					var v3 = cell_vertex_indices[_get_cell_idx(x-1, y, z-1)]
					var v4 = cell_vertex_indices[_get_cell_idx(x-1, y, z)]
					
					if v1 != -1 and v2 != -1 and v3 != -1 and v4 != -1:
						if is_inside: indices.append_array([v1, v2, v3, v1, v3, v4])
						else:         indices.append_array([v1, v4, v3, v1, v3, v2])

				# Check Z edge
				if is_inside != (density_map[_get_idx(x, y, z+1)] < ISO_LEVEL) and z < CHUNK_SIZE - 1:
					var v1 = cell_vertex_indices[_get_cell_idx(x, y, z)]
					var v2 = cell_vertex_indices[_get_cell_idx(x-1, y, z)]
					var v3 = cell_vertex_indices[_get_cell_idx(x-1, y-1, z)]
					var v4 = cell_vertex_indices[_get_cell_idx(x, y-1, z)]
					
					if v1 != -1 and v2 != -1 and v3 != -1 and v4 != -1:
						if is_inside: indices.append_array([v1, v2, v3, v1, v3, v4])
						else:         indices.append_array([v1, v4, v3, v1, v3, v2])

	# ==========================================
	# PASS 3: Calculate Smooth Normals
	# ==========================================
	for i in range(0, indices.size(), 3):
		var i1 = indices[i]; var i2 = indices[i+1]; var i3 = indices[i+2]
		var v1 = vertices[i1]; var v2 = vertices[i2]; var v3 = vertices[i3]
		
		# Cross product calculates the perpendicular direction the face is pointing
		var normal = (v2 - v1).cross(v3 - v1).normalized()
		
		# Add face normal to all three vertices
		normals[i1] += normal
		normals[i2] += normal
		normals[i3] += normal
		
	# Normalize final vertex normals
	for i in range(normals.size()):
		normals[i] = normals[i].normalized()

	# ------------------------------------------
	# FINALIZE: Just save the arrays! Don't build the mesh here!sdsadwa
	# ------------------------------------------
	out_vertices = vertices
	out_normals = normals
	out_indices = indices
