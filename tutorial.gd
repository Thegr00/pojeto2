extends Node3D 

@export var respawn_point: Marker3D
@onready var anim_player = $AnimationPlayer 

# Make sure this name exactly matches what your CanvasLayer is called in the Scene Tree!
@onready var objective_manager = $ObjectiveUI 

var waiting_for_input = false

func _ready():
	# Connect the megaphone signal to our resume function
	if objective_manager:
		objective_manager.tutorial_finished.connect(resume_cutscene)
		objective_manager.rings_finished.connect(resume_cutscene) 
	else:
		print("ERROR: Level script could not find ObjectiveUI!")

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
	if player:
		player.set_physics_process(true) 
		
	# NEW: Tell the UI to start the rings the exact moment the player gets control!
	if objective_manager:
		objective_manager.start_ring_objective()
	else:
		print("ERROR: Could not find objective manager to start rings!")

func pause_cutscene_for_gameplay():
	print("Pausing animation for gameplay...")
	anim_player.pause()
# The Objective Manager triggers this when the tutorial is done
func resume_cutscene():
	print("Tutorial finished! Resuming animation...")
	anim_player.play()
