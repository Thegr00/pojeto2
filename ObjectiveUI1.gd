extends CanvasLayer

@onready var label = $Label

@export var total_rings: int = 5 # Change this in the inspector for each level!
var rings_caught: int = 0

func _ready() -> void:
	update_ring_text()

func ring_collected() -> void:
	rings_caught += 1
	update_ring_text()
	
	if rings_caught >= total_rings:
		finish_level()

func update_ring_text() -> void:
	label.text = "Rings: " + str(rings_caught) + " / " + str(total_rings)
	
	# Keep that nice pop animation!
	var pop_tween = create_tween()
	pop_tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.1)
	pop_tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.1)

func finish_level() -> void:
	label.text = "Level Complete!"
	# Add whatever logic you need here to transition to the next level or show a win screen!
