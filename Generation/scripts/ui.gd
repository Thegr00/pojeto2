extends CanvasLayer

@onready var score_label: Label = $Label

func _ready() -> void:
	# Because GameManager is an Autoload, we can call it directly by name!
	GameManager.score_updated.connect(_on_score_updated)
	
	# Set the starting text
	score_label.text = "Score: 0"

func _on_score_updated(new_score: int) -> void:
	score_label.text = "Score: " + str(new_score)
