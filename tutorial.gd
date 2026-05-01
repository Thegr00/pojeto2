extends Node3D 

@onready var anim_player = $AnimationPlayer 
var waiting_for_input = false


func pause_for_dialogue():
	anim_player.pause()
	waiting_for_input = true


func _input(event):
	
	if event.is_action_pressed("ui_accept") and waiting_for_input:
		waiting_for_input = false
		anim_player.play() 
