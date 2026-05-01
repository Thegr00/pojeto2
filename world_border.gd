extends Area3D

@export var respawn_point: Marker3D

func _on_body_entered(body):
	if body.name == "mangas3p":
		if respawn_point != null:
			body.global_position = respawn_point.global_position
