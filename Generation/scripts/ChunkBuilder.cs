using Godot;
using System;
using System.Collections.Generic;

[GlobalClass]
public partial class ChunkBuilder : RefCounted
{
	public const int ChunkSize = 16;
	public const float VoxelSize = 2.0f;
	public const float IsoLevel = 0.0f;

	// Standard fields
	public Vector3I chunk_pos;
	public GodotObject noise_data;
	
	public Godot.Collections.Array local_segments_gd { get; set; }

	public bool is_empty = true;
	public Vector3[] out_vertices;
	public Vector3[] out_normals;
	public int[] out_indices;
	public Color[] out_colors;
	public Vector3[] out_collision_faces;

	// === 🚨 HAZARD COORDINATES 🚨 ===
	public Vector3[] out_bomb_positions;
	public Vector3[] out_laser_positions;
	// =====================================

	private FastNoiseLite _warpNoise;
	private FastNoiseLite _heightNoise;
	private FastNoiseLite _detailNoise;

	private struct Segment
	{
		public Vector3 Start;
		public Vector3 End;
	}

	public void execute_job()
	{
		_warpNoise = (FastNoiseLite)noise_data.Get("warp_noise");
		_heightNoise = (FastNoiseLite)noise_data.Get("height_noise");
		_detailNoise = (FastNoiseLite)noise_data.Get("detail_noise");

		Segment[] localSegments = new Segment[local_segments_gd.Count];
		for (int i = 0; i < local_segments_gd.Count; i++)
		{
			Godot.Collections.Dictionary dict = (Godot.Collections.Dictionary)local_segments_gd[i];
			localSegments[i] = new Segment
			{
				Start = (Vector3)dict["start"],
				End = (Vector3)dict["end"]
			};
		}

		// Calculate terrain density
		float[] densityMap = GenerateDensityField(localSegments);

		// We only generate meshes AND hazards if the chunk actually has terrain!
		if (!is_empty)
		{
			// Pass the densityMap in so we can check for empty air!
			GenerateHazardPositions(localSegments, densityMap);
			BuildMeshAndCollision(densityMap);
		}
		else
		{
			// Failsafe: If the chunk is empty air, ensure hazard arrays are empty, not null!
			out_bomb_positions = new Vector3[0];
			out_laser_positions = new Vector3[0];
		}
	}

	// === 🚨 THE SPATIALLY AWARE HAZARD GENERATOR 🚨 ===
	private void GenerateHazardPositions(Segment[] segments, float[] densityMap)
	{
		List<Vector3> bombs = new List<Vector3>();
		List<Vector3> lasers = new List<Vector3>();

		int seed = (chunk_pos.X * 8921 ^ chunk_pos.Y * 239 ^ chunk_pos.Z * 34891).GetHashCode();
		Random rng = new Random(seed);
		if (rng.NextDouble() > 0.25) 
	{
		out_bomb_positions = new Vector3[0];
		out_laser_positions = new Vector3[0];
		return;
	}
		// 1. We will sample a bunch of random spots to find the best ones
		int sampleCount = 40; 
		int maxBombsToSpawn = rng.Next(1, 3); // Maximum bombs you want per chunk
		int padding = 2; 

		// This will store our safe spots. Key = How "blank" the space is, Value = Coordinates
		List<KeyValuePair<float, Vector3I>> safeCandidates = new List<KeyValuePair<float, Vector3I>>();

		for (int i = 0; i < sampleCount; i++)
		{
			int x = rng.Next(padding, ChunkSize - padding);
			int y = rng.Next(padding, ChunkSize - padding);
			int z = rng.Next(padding, ChunkSize - padding);

			// Check the noise/density map!
			float density = GetDensity(densityMap, x, y, z);

			// 🚨 THE FIX: > IsoLevel means AIR! 
			// We only consider spots where density > 5.0f (meaning it is a good distance away from ANY block/wall)
			if (density > 5.0f) 
			{
				safeCandidates.Add(new KeyValuePair<float, Vector3I>(density, new Vector3I(x, y, z)));
			}
		}

		// 2. YOUR IDEA: Sort the list so the spots with the LEAST noise / MOST open air are at the top!
		safeCandidates.Sort((a, b) => b.Key.CompareTo(a.Key));

		// 3. Spawn the bombs in those perfect blank spots
		int spawned = 0;
		foreach (var candidate in safeCandidates)
		{
				if (spawned >= maxBombsToSpawn) break;

			Vector3I localPos = candidate.Value;
			
			// Convert to Global Coordinates so they actually appear in the chunk!
			float wx = (localPos.X + chunk_pos.X * ChunkSize) * VoxelSize;
			float wy = (localPos.Y + chunk_pos.Y * ChunkSize) * VoxelSize;
			float wz = (localPos.Z + chunk_pos.Z * ChunkSize) * VoxelSize;

			bombs.Add(new Vector3(wx, wy, wz));
			spawned++;
		}

		// Lasers temporarily disabled for debugging
		bool spawnLaser = false; 
		if (spawnLaser && segments != null && segments.Length > 0)
		{
			int randomSegmentIndex = rng.Next(segments.Length);
			float t = (float)rng.NextDouble();
			Vector3 pos = segments[randomSegmentIndex].Start.Lerp(segments[randomSegmentIndex].End, t);
			lasers.Add(pos);
		}

		out_bomb_positions = bombs.ToArray();
		out_laser_positions = lasers.ToArray();
	}

	private float GetDistanceToSegments(Vector3 pos, Segment[] segments)
	{
		if (segments.Length == 0) return 9999.0f;

		float minDistSq = 99999999.0f;

		for (int i = 0; i < segments.Length; i++)
		{
			Vector3 p1 = segments[i].Start;
			Vector3 p2 = segments[i].End;

			Vector3 lineVec = p2 - p1;
			Vector3 pointVec = pos - p1;

			float lineLenSq = lineVec.LengthSquared();
			float t = 0.0f;
			if (lineLenSq > 0.00001f) 
			{
				t = Mathf.Clamp(pointVec.Dot(lineVec) / lineLenSq, 0.0f, 1.0f);
			}

			Vector3 projection = p1 + lineVec * t;
			float dSq = pos.DistanceSquaredTo(projection);
			if (dSq < minDistSq)
			{
				minDistSq = dSq;
			}
		}

		return Mathf.Sqrt(minDistSq);
	}

	private float[] GenerateDensityField(Segment[] localSegments)
	{
		int size = ChunkSize + 2;
		float[] map = new float[size * size * size];

		int solidCount = 0;
		int totalInnerVoxels = ChunkSize * ChunkSize * ChunkSize;
		is_empty = true;

		int idx = 0;
		for (int z = -1; z < ChunkSize + 1; z++)
		{
			for (int y = -1; y < ChunkSize + 1; y++)
			{
				for (int x = -1; x < ChunkSize + 1; x++)
				{
					Vector3 worldPos = (new Vector3(x, y, z) + new Vector3(chunk_pos.X * ChunkSize, chunk_pos.Y * ChunkSize, chunk_pos.Z * ChunkSize)) * VoxelSize;
					float d = CalculateSdf(worldPos, localSegments);
					map[idx] = d;

					if (x >= 0 && x < ChunkSize && y >= 0 && y < ChunkSize && z >= 0 && z < ChunkSize)
					{
						if (d < IsoLevel)
						{
							solidCount++;
						}
					}
					idx++;
				}
			}
		}

		float fillRatio = (float)solidCount / totalInnerVoxels;
		if (fillRatio < 0.04f)
		{
			InjectIslands(map, localSegments);
		}

		idx = 0;
		for (int z = -1; z < ChunkSize + 1; z++)
		{
			for (int y = -1; y < ChunkSize + 1; y++)
			{
				for (int x = -1; x < ChunkSize + 1; x++)
				{
					if (x >= 0 && x < ChunkSize && y >= 0 && y < ChunkSize && z >= 0 && z < ChunkSize)
					{
						if (map[idx] < IsoLevel)
						{
							is_empty = false;
						}
					}
					idx++;
				}
			}
		}

		return map;
	}

	private void InjectIslands(float[] map, Segment[] localSegments)
	{
		int seed = (chunk_pos.X * 73856 ^ chunk_pos.Y * 1919 ^ chunk_pos.Z * 83492791).GetHashCode();
		Random rng = new Random(seed);

		int numIslands = rng.Next(1, 4);

		for (int i = 0; i < numIslands; i++)
		{
			Vector3 center = new Vector3(
				rng.Next(3, ChunkSize - 2),
				rng.Next(3, ChunkSize - 2),
				rng.Next(3, ChunkSize - 2)
			);
			
			float radius = (float)(rng.NextDouble() * 3.0 + 1.5);

			int idx = 0;
			for (int z = -1; z < ChunkSize + 1; z++)
			{
				for (int y = -1; y < ChunkSize + 1; y++)
				{
					for (int x = -1; x < ChunkSize + 1; x++)
					{
						Vector3 localPos = new Vector3(x, y, z);
						float dist = localPos.DistanceTo(center);
						
						float islandSdf = (dist - radius) * 10.0f;
						
						if (islandSdf < map[idx])
						{
							Vector3 worldPos = (localPos + new Vector3(chunk_pos.X * ChunkSize, chunk_pos.Y * ChunkSize, chunk_pos.Z * ChunkSize)) * VoxelSize;
							float distToPath = GetDistanceToSegments(worldPos, localSegments);
							float safetyTube = 10.0f - distToPath;
							
							float finalD = Mathf.Max(islandSdf, safetyTube);
							map[idx] = Mathf.Min(map[idx], finalD);
						}
						idx++;
					}
				}
			}
		}
	}

	private float CalculateSdf(Vector3 pos, Segment[] localSegments)
	{
		float warp = _warpNoise.GetNoise3D(pos.X * 0.5f, 0.0f, pos.Z * 0.5f) * 40.0f;
		float pillarNoise = _heightNoise.GetNoise3D(pos.X + warp, pos.Y * 0.1f, pos.Z + warp);
		float baseDensity = -pillarNoise * 50.0f;

		float terracing = Mathf.Sin(pos.Y * 0.08f) * 15.0f;
		baseDensity += terracing;

		float caveNoise = _detailNoise.GetNoise3D(pos.X * 0.8f, pos.Y * 1.5f, pos.Z * 0.8f);
		float caveCarver = Mathf.Abs(caveNoise) * 90.0f;

		float distToPath = GetDistanceToSegments(pos, localSegments);
		float safetyTube = 10.0f - distToPath;

		float finalD = Mathf.Max(baseDensity, 25.0f - caveCarver);
		finalD = Mathf.Max(finalD, safetyTube);

		if (pos.Z < 20.0f && pos.Z > -80.0f)
		{
			float distFromCenter = Mathf.Sqrt(pos.X * pos.X + pos.Y * pos.Y);
			float progress = Mathf.Clamp((pos.Z - 20.0f) / (-80.0f - 20.0f), 0.0f, 1.0f);
			float currentRadius = Mathf.Lerp(30.0f, 10.0f, progress);
			float runwayCarver = currentRadius - distFromCenter;
			finalD = Mathf.Max(finalD, runwayCarver);
		}

		return finalD;
	}

	private float GetDensity(float[] map, int x, int y, int z)
	{
		int mx = x + 1;
		int my = y + 1;
		int mz = z + 1;
		int size = ChunkSize + 2;
		return map[mx + size * (my + size * mz)];
	}

	private Color GetVoxelColor(float worldX, float worldY, float worldZ, Vector3 normal)
	{
		Color baseColor;
		
		if (worldY > 60.0f)
			baseColor = new Color(0.85f, 0.85f, 0.88f);
		else if (worldY > -20.0f)
			baseColor = new Color(0.25f, 0.25f, 0.28f);
		else if (worldY > -60.0f)
			baseColor = new Color(0.08f, 0.08f, 0.09f);
		else
			baseColor = new Color(0.6f, 0.1f, 0.05f);

		int checker = Mathf.FloorToInt(Mathf.Floor(worldX / 2.0f) + Mathf.Floor(worldY / 2.0f) + Mathf.Floor(worldZ / 2.0f)) % 2;
		float brightness = (checker == 0) ? 1.0f : 0.92f;

		if (normal.Y == 0.0f)
			brightness *= 0.85f;
		else if (normal.Y < 0.0f)
			brightness *= 0.65f;

		return baseColor * brightness;
	}

	private void BuildMeshAndCollision(float[] densityMap)
	{
		List<Vector3> vertices = new List<Vector3>();
		List<Vector3> normals = new List<Vector3>();
		List<int> indices = new List<int>();
		List<Color> colors = new List<Color>();

		Vector3I[] dirs = new Vector3I[]
		{
			Vector3I.Right, Vector3I.Left, Vector3I.Up, Vector3I.Down, Vector3I.Back, Vector3I.Forward
		};

		Vector3[][] faceVerts = new Vector3[][]
		{
			new Vector3[] { new Vector3(1,0,1), new Vector3(1,0,0), new Vector3(1,1,0), new Vector3(1,1,1) },
			new Vector3[] { new Vector3(0,0,0), new Vector3(0,0,1), new Vector3(0,1,1), new Vector3(0,1,0) },
			new Vector3[] { new Vector3(0,1,1), new Vector3(1,1,1), new Vector3(1,1,0), new Vector3(0,1,0) },
			new Vector3[] { new Vector3(0,0,0), new Vector3(1,0,0), new Vector3(1,0,1), new Vector3(0,0,1) },
			new Vector3[] { new Vector3(1,0,1), new Vector3(0,0,1), new Vector3(0,1,1), new Vector3(1,1,1) },
			new Vector3[] { new Vector3(0,0,0), new Vector3(1,0,0), new Vector3(1,1,0), new Vector3(0,1,0) }
		};

		int indexOffset = 0;

		for (int z = 0; z < ChunkSize; z++)
		{
			for (int y = 0; y < ChunkSize; y++)
			{
				for (int x = 0; x < ChunkSize; x++)
				{
					float d = GetDensity(densityMap, x, y, z);
					if (d >= IsoLevel) continue;

					Vector3 worldPos = (new Vector3(x, y, z) - (Vector3.One * 0.5f)) * VoxelSize;
					float wx = (x + chunk_pos.X * ChunkSize) * VoxelSize;
					float wy = (y + chunk_pos.Y * ChunkSize) * VoxelSize;
					float wz = (z + chunk_pos.Z * ChunkSize) * VoxelSize;

					for (int i = 0; i < 6; i++)
					{
						int nx = x + dirs[i].X;
						int ny = y + dirs[i].Y;
						int nz = z + dirs[i].Z;

						if (GetDensity(densityMap, nx, ny, nz) >= IsoLevel)
						{
							Vector3 normal = new Vector3(dirs[i].X, dirs[i].Y, dirs[i].Z);
							Color faceColor = GetVoxelColor(wx, wy, wz, normal);

							for (int v = 0; v < 4; v++)
							{
								vertices.Add(worldPos + (faceVerts[i][v] * VoxelSize));
								normals.Add(normal);
								colors.Add(faceColor);
							}

							indices.AddRange(new int[] {
								indexOffset, indexOffset + 1, indexOffset + 2,
								indexOffset, indexOffset + 2, indexOffset + 3
							});
							indexOffset += 4;
						}
					}
				}
			}
		}

		out_vertices = vertices.ToArray();
		out_normals = normals.ToArray();
		out_indices = indices.ToArray();
		out_colors = colors.ToArray();

		out_collision_faces = new Vector3[indices.Count];
		for (int i = 0; i < indices.Count; i++)
		{
			out_collision_faces[i] = vertices[indices[i]];
		}
	}
}
