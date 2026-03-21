extends Node

var current_score: int = 0
var is_flying: bool = false
var points_per_second: float = 10.0 # How many points you get for 1 second of flying
var _internal_score: float = 0.0

# This signal shouts to the rest of the game when the score changes
signal score_updated(new_score: int)

func _ready() -> void:
	current_score = 0
	_internal_score = 0.0
	is_flying = false 

func _process(delta: float) -> void:
	if is_flying:
		# Add points smoothly based on frame time
		_internal_score += points_per_second * delta
		
		# Convert to an integer so the UI doesn't show decimals
		var new_int_score = int(_internal_score)
		
		# If the integer score went up, update it and tell the UI!
		if new_int_score > current_score:
			current_score = new_int_score
			score_updated.emit(current_score)

func start_flying() -> void:
	is_flying = true

func stop_flying() -> void:
	is_flying = false
