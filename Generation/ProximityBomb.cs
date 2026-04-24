using Godot;
using System;

public partial class ProximityBomb : Area3D
{
	[Export] public float RotationSpeed = 2.0f;
	[Export] public float MinScale = 1.0f;
	[Export] public float MaxScale = 2.5f; // How big it gets when fully expanded
	[Export] public float PulseSpeed = 4.0f; // How fast it breathes

	// 1. Add a reference for the explosion scene
	private PackedScene _explosionScene;
	private double _timePassed = 0;

	public override void _Ready()
	{
		// 2. Load the explosion scene. 
		// MAKE SURE this path exactly matches what you named your explosion scene!
		_explosionScene = GD.Load<PackedScene>("res://explosion_effect.tscn");

		// Automatically connect the collision signal so we don't have to do it in the editor!
		BodyEntered += OnBodyEntered;
	}

	public override void _Process(double delta)
	{
		_timePassed += delta;

		// Tumble and rotate the cube
		RotateY(RotationSpeed * (float)delta);
		RotateX((RotationSpeed * 0.5f) * (float)delta);

		// Calculate the pulsing scale using a Sine wave
		float sinWave = (Mathf.Sin((float)_timePassed * PulseSpeed) + 1.0f) / 2.0f;
		
		// Lerp smoothly blends between your MinScale and MaxScale based on the wave
		float currentScale = Mathf.Lerp(MinScale, MaxScale, sinWave);

		// Apply the scale to the Area3D (this scales both the Mesh and the Hitbox!)
		Scale = new Vector3(currentScale, currentScale, currentScale);
	}

	private void OnBodyEntered(Node3D body)
	{
		// Check if the thing that touched the bomb is the player
		if (body.Name == "Player") // Make sure "Player" exactly matches your player node's name!
		{
			GD.Print("Player touched the Pufferfish Bomb! BOOM!");
			Explode();
		}
	}

	// 3. The new C# Explode function
	private void Explode()
	{
		if (_explosionScene != null)
		{
			// Create the explosion as a GPU particle node
			GpuParticles3D currentExplosion = _explosionScene.Instantiate<GpuParticles3D>();
			
			// Add it to the main game world (NOT as a child of the bomb, because the bomb is about to be deleted!)
			GetTree().CurrentScene.AddChild(currentExplosion);
			
			// Move the explosion to exactly where the bomb is
			currentExplosion.GlobalPosition = GlobalPosition;
			
			// Light the fuse!
			currentExplosion.Emitting = true;
		}
		else
		{
			GD.PrintErr("Explosion scene not found! Check the file path.");
		}

		// Destroy the original bomb node so it disappears!
		QueueFree();
	}
}
