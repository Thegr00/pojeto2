using Godot;
using System;
using System.Collections.Generic;

[GlobalClass]
public partial class ChunkBuilder : RefCounted
{
	public const int ChunkSize = 32;
	public const float VoxelSize = 2.0f;
	public const float IsoLevel = 0.0f;

	// Using exact GDScript variable names so your TerrainChunk.gd doesn't break!
    public Vector3I chunk_pos { get; set; }
    public GodotObject flight_path { get; set; }
    public GodotObject noise_data { get; set; }

    public bool is_empty { get; set; } = true;
    public Vector3[] out_vertices { get; set; }
    public Vector3[] out_normals { get; set; }
    public int[] out_indices { get; set; }
    public Color[] out_colors { get; set; }
    public Vector3[] out_collision_faces { get; set; }

    // Cached noise references to keep things fast
    private FastNoiseLite _warpNoise;
    private FastNoiseLite _heightNoise;
    private FastNoiseLite _detailNoise;

    public void execute_job()
    {
        // Grab the noise generators from your GDScript object
        _warpNoise = (FastNoiseLite)noise_data.Get("warp_noise");
        _heightNoise = (FastNoiseLite)noise_data.Get("height_noise");
        _detailNoise = (FastNoiseLite)noise_data.Get("detail_noise");

        Vector3 chunkCenterWorld = (new Vector3(chunk_pos.X, chunk_pos.Y, chunk_pos.Z) * ChunkSize * VoxelSize) + (Vector3.One * ChunkSize * VoxelSize * 0.5f);
        float searchRadius = (ChunkSize * VoxelSize) * 2.0f;

        Godot.Collections.Array localSegments = (Godot.Collections.Array)flight_path.Call("get_local_segments", chunkCenterWorld, searchRadius);
        float[] densityMap = GenerateDensityField(localSegments);

        if (!is_empty)
        {
            BuildMeshAndCollision(densityMap);
        }
    }

    private float[] GenerateDensityField(Godot.Collections.Array localSegments)
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

    private float CalculateSdf(Vector3 pos, Godot.Collections.Array localSegments)
    {
        float warp = _warpNoise.GetNoise3D(pos.X * 0.5f, 0.0f, pos.Z * 0.5f) * 40.0f;
        float pillarNoise = _heightNoise.GetNoise3D(pos.X + warp, pos.Y * 0.1f, pos.Z + warp);
        float baseDensity = -pillarNoise * 50.0f;

        float terracing = Mathf.Sin(pos.Y * 0.08f) * 15.0f;
        baseDensity += terracing;

        float caveNoise = _detailNoise.GetNoise3D(pos.X * 0.8f, pos.Y * 1.5f, pos.Z * 0.8f);
        float caveCarver = Mathf.Abs(caveNoise) * 90.0f;

        // Calling back to GDScript for distance
        float distToPath = (float)flight_path.Call("get_distance_to_segments", pos, localSegments);
        float safetyTube = 35.0f - distToPath;

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
