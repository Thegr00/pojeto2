extends Node

signal score_updated(new_score: int)

# --- Core Stats ---
var total_score: int = 0
var unbanked_score: float = 0.0 
var current_multiplier: float = 1.0

# --- Settings ---
var max_multiplier: float = 10.0
var combo_timeout: float = 1.0 
var points_per_second: float = 10.0 # Brought over from GameManager!

# Internal trackers
var _time_away_from_walls: float = 0.0
var _passive_score_accumulator: float = 0.0
var _is_proximity_flying: bool = false
var is_flying: bool = false 

func _process(delta: float) -> void:
	if not is_flying:
		return
		
	# 1. Add Passive Points (Just for staying alive)
	_passive_score_accumulator += points_per_second * delta
	if _passive_score_accumulator >= 1.0:
		var int_points = int(_passive_score_accumulator)
		total_score += int_points
		_passive_score_accumulator -= int_points
		score_updated.emit(total_score) # Tell UI to update!

	# 2. Handle Proximity Combo Timeouts
	if _is_proximity_flying:
		_time_away_from_walls = 0.0
	elif unbanked_score > 0:
		_time_away_from_walls += delta
		if _time_away_from_walls >= combo_timeout:
			bank_score()

func start_flying() -> void:
	is_flying = true

func stop_flying() -> void:
	is_flying = false

# YOUR PLAYER SCRIPT MUST CALL THIS EVERY FRAME THEY ARE CLOSE TO A WALL!
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
		score_updated.emit(total_score) # Update UI!
		print("BANKED! +", final_addition, " | Total Score: ", total_score)
		
		unbanked_score = 0.0
		current_multiplier = 1.0

# Player hit the wall. Bank everything they had!
func crash() -> void:
	is_flying = false
	if unbanked_score > 0:
		var final_addition = int(unbanked_score)
		total_score += final_addition
		score_updated.emit(total_score) # Update UI!
		print("CRASH CASH-OUT! +", final_addition, " | Final Score: ", total_score)
		
	unbanked_score = 0.0
	current_multiplier = 1.0
	_is_proximity_flying = false

# Wipes everything clean for a new run
func prepare_for_restart() -> void:
	total_score = 0
	unbanked_score = 0.0
	current_multiplier = 1.0
	_time_away_from_walls = 0.0
	_passive_score_accumulator = 0.0
	_is_proximity_flying = false
	is_flying = false
	score_updated.emit(total_score) # Forces the UI back to 0!
	print("ScoreManager: Internal variables wiped for restart.")
