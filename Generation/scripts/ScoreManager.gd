extends Node

# --- Core Stats ---
var total_score: int = 0
var unbanked_score: float = 0.0 
var current_multiplier: float = 1.0

# --- Settings ---
var max_multiplier: float = 10.0
var combo_timeout: float = 1.0 

# Internal trackers
var _time_away_from_walls: float = 0.0
var _is_proximity_flying: bool = false

func _process(delta: float) -> void:
	if _is_proximity_flying:
		_time_away_from_walls = 0.0
	elif unbanked_score > 0:
		_time_away_from_walls += delta
		if _time_away_from_walls >= combo_timeout:
			bank_score()

func add_proximity_points(delta: float, closeness_factor: float) -> void:
	_is_proximity_flying = true
	
	current_multiplier += (closeness_factor * delta * 2.0)
	if current_multiplier > max_multiplier:
		current_multiplier = max_multiplier
		
	var base_points_per_second = 100.0 * closeness_factor
	unbanked_score += (base_points_per_second * current_multiplier) * delta

func stop_scoring() -> void:
	_is_proximity_flying = false

func bank_score() -> void:
	if unbanked_score > 0:
		var final_addition = int(unbanked_score)
		total_score += final_addition
		print("BANKED! +", final_addition, " | Total Score: ", total_score)
		
		unbanked_score = 0.0
		current_multiplier = 1.0

# Player hit the wall. Bank everything they had!
func crash() -> void:
	if unbanked_score > 0:
		var final_addition = int(unbanked_score)
		total_score += final_addition
		print("CRASH CASH-OUT! +", final_addition, " | Final Score: ", total_score)
		
	unbanked_score = 0.0
	current_multiplier = 1.0
	_is_proximity_flying = false

# Wipes everything clean for a new run
func reset_scores() -> void:
	total_score = 0
	unbanked_score = 0.0
	current_multiplier = 1.0
	_time_away_from_walls = 0.0
	_is_proximity_flying = false
	print("Scores Reset!")
func prepare_for_restart() -> void:
	total_score = 0
	unbanked_score = 0.0
	current_multiplier = 1.0
	_time_away_from_walls = 0.0
	_is_proximity_flying = false
	print("ScoreManager: Internal variables wiped for restart.")
