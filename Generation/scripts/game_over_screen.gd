extends CanvasLayer

@onready var score_label: Label = $Label/VBoxContainer/Label
@onready var restart_button: Button = $Label/VBoxContainer/RestartButton
func _ready() -> void:
	restart_button.pressed.connect(_on_restart_pressed)

func set_final_score(score: int) -> void:
	score_label.text = "Final Score: " + str(score)

func _on_restart_pressed() -> void:
	# 1. WIPE THE DATA FIRST
	ScoreManager.prepare_for_restart()
	
	# 2. Unpause
	get_tree().paused = false
	
	# 3. Reload
	get_tree().reload_current_scene()
