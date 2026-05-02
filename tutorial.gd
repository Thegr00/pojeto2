extends Node3D 

@export var respawn_point: Marker3D
@onready var anim_player = $AnimationPlayer 
var waiting_for_input = false


func pause_for_dialogue():
	anim_player.pause()
	waiting_for_input = true


func _input(event):
	if event.is_action_pressed("ui_accept") and waiting_for_input:
		waiting_for_input = false
		anim_player.play() 

func pause_entire_game():
	get_tree().paused = true

func unpause_entire_game():
	get_tree().paused = false

func end_cutscene():
	var player = $mangas3p
	player.set_physics_process(true) 
