class_name ChunkBuilder
extends RefCounted

const CHUNK_SIZE = 32
const VOXEL_SIZE = 2.0
const ISO_LEVEL = 0.0

var chunk_pos: Vector3i
var flight_path: FlightPath
var noise_data: TerrainNoise

var is_empty := true
var out_vertices: PackedVector3Array
var out_normals: PackedVector3Array
var out_indices: PackedInt32Array
var out_colors: PackedColorArray
var out_collision_faces: PackedVector3Array

func execute_job() -> void:
	var chunk_center_world = (Vector3(chunk_pos) * CHUNK_SIZE * VOXEL_SIZE) + (Vector3.ONE * CHUNK_SIZE * VOXEL_SIZE * 0.5)
	var search_radius = (CHUNK_SIZE * VOXEL_SIZE) * 2.0
	
	var local_segments = flight_path.get_local_segments(chunk_center_world, search_radius)
	var density_map = _generate_density_field(local_segments)
	
	if not is_empty:
		_build_mesh_and_collision(density_map)

func _generate_density_field(local_segments: Array) -> PackedFloat32Array:
	# FIX: We calculate 1 extra block on all sides (-1 to 32) so chunk borders match perfectly!
	var size = CHUNK_SIZE + 2 
	var map = PackedFloat32Array()
	map.resize(size * size * size)
	
	var idx = 0
	for z in range(-1, CHUNK_SIZE + 1):
		for y in range(-1, CHUNK_SIZE + 1):
			for x in range(-1, CHUNK_SIZE + 1):
				var world_pos = (Vector3(x, y, z) + Vector3(chunk_pos * CHUNK_SIZE)) * VOXEL_SIZE
				var d = calculate_sdf(world_pos, local_segments)
				map[idx] = d
				
				# Only check emptiness for the actual chunk core (0 to 31)
				if x >= 0 and x < CHUNK_SIZE and y >= 0 and y < CHUNK_SIZE and z >= 0 and z < CHUNK_SIZE:
					if d < ISO_LEVEL:
						is_empty = false
				idx += 1
	return map

func calculate_sdf(pos: Vector3, local_segments: Array) -> float:
	var warp = noise_data.warp_noise.get_noise_3d(pos.x * 0.5, 0.0, pos.z * 0.5) * 40.0
	var pillar_noise = noise_data.height_noise.get_noise_3d(pos.x + warp, pos.y * 0.1, pos.z + warp)
	var base_density = -pillar_noise * 50.0 
	
	var terracing = sin(pos.y * 0.08) * 15.0
	base_density += terracing
	
	var cave_noise = noise_data.detail_noise.get_noise_3d(pos.x * 0.8, pos.y * 1.5, pos.z * 0.8)
	var cave_carver = abs(cave_noise) * 90.0
	
	var dist_to_path = flight_path.get_distance_to_segments(pos, local_segments)
	var safety_tube = 35.0 - dist_to_path
	
	var final_d = max(base_density, 25.0 - cave_carver)
	final_d = max(final_d, safety_tube)
	return final_d

func _get_density(map: PackedFloat32Array, x: int, y: int, z: int) -> float:
	var mx = x + 1
	var my = y + 1
	var mz = z + 1
	var size = CHUNK_SIZE + 2
	return map[mx + size * (my + size * mz)]

# FIX: This adds "fake lighting" and a checkerboard pattern to make it look like actual 3D blocks!
func get_voxel_color(world_x: float, world_y: float, world_z: float, normal: Vector3) -> Color:
	var base_color: Color
	if world_y > 80.0: 
		base_color = Color(0.9, 0.9, 0.95) # Snow
	elif world_y > -40.0: 
		base_color = Color(0.3, 0.6, 0.25) # Grass/Dirt
	else: 
		base_color = Color(0.4, 0.4, 0.45) # Rock
		
	# Checkerboard pattern
	var checker = int(floor(world_x/2.0) + floor(world_y/2.0) + floor(world_z/2.0)) % 2
	var brightness = 1.0 if checker == 0 else 0.92
	
	# Darken faces pointing sideways or down
	if normal.y == 0:
		brightness *= 0.85 # Sides get slightly darker
	elif normal.y < 0:
		brightness *= 0.65 # Bottom is darkest
		
	return base_color * brightness

func _build_mesh_and_collision(density_map: PackedFloat32Array) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var colors := PackedColorArray()
	
	var dirs = [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD]
	var face_verts = [
		[Vector3(1,0,1), Vector3(1,0,0), Vector3(1,1,0), Vector3(1,1,1)],
		[Vector3(0,0,0), Vector3(0,0,1), Vector3(0,1,1), Vector3(0,1,0)],
		[Vector3(0,1,1), Vector3(1,1,1), Vector3(1,1,0), Vector3(0,1,0)],
		[Vector3(0,0,0), Vector3(1,0,0), Vector3(1,0,1), Vector3(0,0,1)],
		[Vector3(1,0,1), Vector3(0,0,1), Vector3(0,1,1), Vector3(1,1,1)],
		[Vector3(0,0,0), Vector3(1,0,0), Vector3(1,1,0), Vector3(0,1,0)]
	]

	var index_offset = 0
	
	for z in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			for x in range(CHUNK_SIZE):
				
				var d = _get_density(density_map, x, y, z)
				if d >= ISO_LEVEL: continue 
					
				var world_pos = (Vector3(x, y, z) - Vector3.ONE * 0.5) * VOXEL_SIZE
				
				var wx = (x + chunk_pos.x * CHUNK_SIZE) * VOXEL_SIZE
				var wy = (y + chunk_pos.y * CHUNK_SIZE) * VOXEL_SIZE
				var wz = (z + chunk_pos.z * CHUNK_SIZE) * VOXEL_SIZE
				
				for i in range(6):
					var nx = x + dirs[i].x
					var ny = y + dirs[i].y
					var nz = z + dirs[i].z
					
					# If neighbor is Air, draw this face
					if _get_density(density_map, nx, ny, nz) >= ISO_LEVEL:
						var normal = Vector3(dirs[i])
						var face_color = get_voxel_color(wx, wy, wz, normal)
						
						for v in range(4):
							vertices.append(world_pos + (face_verts[i][v] * VOXEL_SIZE))
							normals.append(normal)
							colors.append(face_color) 
							
						indices.append_array([
							index_offset, index_offset + 1, index_offset + 2,
							index_offset, index_offset + 2, index_offset + 3
						])
						index_offset += 4

	out_vertices = vertices
	out_normals = normals
	out_indices = indices
	out_colors = colors

	# FIX: Build the collision faces more explicitly for thread safety
	var faces = PackedVector3Array()
	var num_triangles = indices.size() / 3
	faces.resize(indices.size())
	
	for i in range(indices.size()):
		faces[i] = vertices[indices[i]]
		
	out_collision_faces = faces
