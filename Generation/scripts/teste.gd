extends Node3D

# Change "$Player" to whatever your player node is actually named!
@onready var player = $mangas3p

func _input(event):
	# If we press the 'T' key on the keyboard...
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		play_opening_cutscene()

func play_opening_cutscene():
	print("Cutscene starting!") # Helpful to see in the output panel
	
	# 1. Stop the player from moving (assuming you use physics_process for movement)
	player.set_physics_process(false) 
	
	# 2. INSTANT smash cut to black
	DialogueUI.cut_to_black()
	
	# Optional: Wait half a second in pure darkness for dramatic effect
	await get_tree().create_timer(0.5).timeout 
	
	# 3. Start the dialogue IN THE DARK
	var intro_dialogue = [
		{"name": "???", "text": "Should we wake him up?", "portrait_path": "res://mangas ara.png"},
		{"name": "???", "text": "Nah let's wait a bit", "portrait_path": "res://batosta.png"}
	]
	# (I used "res://icon.svg" for the portraits so you don't get errors if you haven't imported art yet!)
	DialogueUI.start_dialogue(intro_dialogue)
	
	# 4. Wait right here until the player clicks through all the text
	await DialogueUI.dialogue_finished
	
	# 5. Remove the black screen to instantly reveal your 3D test room
	DialogueUI.clear_screen()
	
	# 6. Give control back to the player!
	player.set_physics_process(true)
