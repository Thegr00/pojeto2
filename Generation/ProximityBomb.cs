using Godot;
using System;

public partial class ProximityBomb : Area3D
{
	[Export] public float RotationSpeed = 2.0f;
	[Export] public float MinScale = 1.0f;
	[Export] public float MaxScale = 2.5f; // How big it gets when fully expanded
	[Export] public float PulseSpeed = 4.0f; // How fast it breathes

	private double _timePassed = 0;

	public override void _Ready()
	{
		// Automatically connect the collision signal so we don't have to do it in the editor!
		BodyEntered += OnBodyEntered;
	}

	public override void _Process(double delta)
	{
		_timePassed += delta;

		// 1. Tumble and rotate the cube
		RotateY(RotationSpeed * (float)delta);
		RotateX((RotationSpeed * 0.5f) * (float)delta);

		// 2. Calculate the pulsing scale using a Sine wave
		// Mathf.Sin smoothly bounces between -1 and 1. We map it to 0 and 1.
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
			// Add your death logic here (e.g., reloading the scene)
		}
	}
}
