using Godot;

public partial class Laser : Area3D
{
	public override void _Ready()
	{
		// Connect the collision signal
		BodyEntered += OnBodyEntered;
	}

	private void OnBodyEntered(Node3D body)
	{
		if (body.Name == "Player") 
		{
			GD.Print("Player hit the Laser! ZZZAP!");
			// Add your death logic here
		}
	}
}
