extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "jpintro":
		print("Animation finished! Jumping to Main Menu...")
		
		# Make sure this string exactly matches your main menu file path
		get_tree().change_scene_to_file("res://Main_Menu/main_menu.tscn")
