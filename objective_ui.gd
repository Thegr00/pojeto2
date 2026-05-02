extends CanvasLayer

@onready var label = $Label

var player: Node3D
var objective_completed: bool = false

# Set this to whatever Y level you consider "down" enough!
# You can change this in the Inspector later.
@export var target_y_level: float = 40.0 

func _ready() -> void:
	# Hunt down the player using the exact same foolproof method your Portal uses
	player = get_tree().current_scene.find_child("mangas3p", true, false)
	
	if player == null:
		print("ERROR: Objective UI couldn't find the player!")

func _process(_delta: float) -> void:
	# Only check if we have a player AND the objective isn't finished yet
	if player != null and not objective_completed:
		
		# Check if the player's current height is lower than our target
		if player.global_position.y <= target_y_level:
			complete_objective()

func complete_objective() -> void:
	objective_completed = true
	
	# Change the text to celebrate!
	label.text = "Objective Complete!"
	
	# Optional: Wait 3 seconds, then make the text disappear completely
	await get_tree().create_timer(3.0).timeout
	
	# We use a tween to fade it out smoothly so it looks polished
	var fade_tween = create_tween()
	fade_tween.tween_property(label, "modulate:a", 0.0, 1.0)
