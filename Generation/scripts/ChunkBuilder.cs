using Godot;
using System;
using System.Collections.Generic;

[GlobalClass]
public partial class ChunkBuilder : RefCounted
{
	public const int ChunkSize = 16; // UPDATED: Changed from 32 to 16
	public const float VoxelSize = 2.0f;
	public const float IsoLevel = 0.0f;

	// Standard fields
	public Vector3I chunk_pos;
	public GodotObject noise_data;
	
	// NEW: We receive the pre-calculated array from GDScript here!
	public Godot.Collections.Array local_segments_gd { get; set; }

	public bool is_empty = true;
	public Vector3[] out_vertices;
	public Vector3[] out_normals;
	public int[] out_indices;
	public Color[] out_colors;
	public Vector3[] out_collision_faces;

	private FastNoiseLite _warpNoise;
	private FastNoiseLite _heightNoise;
	private FastNoiseLite _detailNoise;

	// A pure C# struct to hold our segment data fast!
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

		// 1. Translate the data GDScript handed us into a hyper-fast C# array
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

		// 2. Pass our pure C# array into the density field generator
		float[] densityMap = GenerateDensityField(localSegments);

		if (!is_empty)
		{
			BuildMeshAndCollision(densityMap);
		}
	}

	// Pure C# Distance Math (No GDScript Toll Booths!)
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
			
			// Avoid division by zero
			if (lineLenSq > 0.00001f) 
			{
				t = Mathf.Clamp(pointVec.Dot(lineVec) / lineLenSq, 0.0f, 1.0f);
			}

			Vector3 projection = p1 + lineVec * t;
			
			// Use distance SQUARED for the loop to avoid slow square roots!
			float dSq = pos.DistanceSquaredTo(projection);
			if (dSq < minDistSq)
			{
				minDistSq = dSq;
			}
		}

		// Only do the expensive square root ONCE at the very end
		return Mathf.Sqrt(minDistSq);
	}

	private float[] GenerateDensityField(Segment[] localSegments)
	{
		int size = ChunkSize + 2;
		float[] map = new float[size * size * size];

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
							is_empty = false;
						}
					}
					idx++;
				}
			}
		}
		return map;
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

		// Call our pure C# method!
		float distToPath = GetDistanceToSegments(pos, localSegments);
		float safetyTube = 10.0f - distToPath;

		float finalD = Mathf.Max(baseDensity, 25.0f - caveCarver);
		finalD = Mathf.Max(finalD, safetyTube);
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
		if (worldY > 80.0f)
			baseColor = new Color(0.9f, 0.9f, 0.95f);
		else if (worldY > -40.0f)
			baseColor = new Color(0.3f, 0.6f, 0.25f);
		else
			baseColor = new Color(0.4f, 0.4f, 0.45f);

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
