using Godot;

public partial class ExplosionEffect : GpuParticles3D
{
	// Preload the explosion scene
	private PackedScene _explosionScene = GD.Load<PackedScene>("res://explosion_effect.tscn");

	public override void _Ready()
	{
		// This automatically deletes the explosion node from the game 
		// as soon as the particles finish their animation!
		Finished += QueueFree;
	}

	public void Explode()
	{
		// 1. Create the explosion
		GpuParticles3D currentExplosion = _explosionScene.Instantiate<GpuParticles3D>();
		
		// 2. Add it to the main game world (NOT as a child of the bomb, 
		// because the bomb is about to be deleted!)
		GetTree().CurrentScene.AddChild(currentExplosion);
		
		// 3. Move it to exactly where the bomb is
		currentExplosion.GlobalPosition = GlobalPosition;
		
		// 4. Light the fuse!
		currentExplosion.Emitting = true;
		
		// 5. Destroy the original node
		QueueFree();
	}
}
