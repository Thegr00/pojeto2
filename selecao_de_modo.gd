extends Control

@onready var start_level = preload("res://Generation/terrain_manager.tscn") as PackedScene

func _on_button_pressed():
	get_tree().change_scene_to_file("res://tutorial.tscn")

func _on_button_2_pressed() -> void:
	pass
	#get_tree().change_scene_to_file("res://Cenas/Campanha.tscn")

func _on_button_3_pressed() -> void:
	get_tree().change_scene_to_packed(start_level)
