extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		var objective_manager = get_tree().current_scene.find_child("ObjectiveUI", true, false)
		
		if objective_manager and objective_manager.has_method("target_reached"):
			# Tell the UI we hit the target!
			objective_manager.target_reached()
