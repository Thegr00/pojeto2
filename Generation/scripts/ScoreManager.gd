extends Node

signal score_updated(new_score: int)
signal combo_updated(unbanked: int, multiplier: float, meter_percent: float)
signal style_event(action_name: String) 
signal score_banked(banked_amount: int)

# --- Core Stats ---
var total_score: int = 0
var unbanked_score: float = 0.0 
var current_multiplier: float = 1.0

# --- Combo Settings ---
var max_multiplier: float = 10.0
var combo_meter: float = 0.0 
var combo_drain_rate: float = 0.35 
var _combo_pause_timer: float = 0.0 # NEW: Stops the 99% flicker!

var is_flying: bool = false 
var points_per_second: float = 10.0
var _passive_score_accumulator: float = 0.0

func _process(delta: float) -> void:
	if not is_flying:
		return
		
	# Passive Points
	_passive_score_accumulator += points_per_second * delta
	if _passive_score_accumulator >= 1.0:
		var int_points = int(_passive_score_accumulator)
		total_score += int_points
		_passive_score_accumulator -= int_points
		score_updated.emit(total_score) 

	# Drain the Combo Meter
	if unbanked_score > 0:
		# NEW: Only drain if the pause timer is finished
		if _combo_pause_timer > 0.0:
			_combo_pause_timer -= delta
		else:
			combo_meter -= combo_drain_rate * delta
			
		combo_meter = clamp(combo_meter, 0.0, 1.0)
		combo_updated.emit(int(unbanked_score), current_multiplier, combo_meter)
		
		# Bank it if it empties!
		if combo_meter <= 0.0:
			bank_score()

func add_proximity_points(delta: float, closeness_factor: float) -> void:
	# THE FIX: Only refill the combo meter if they are DANGEROUSLY close.
	# closeness_factor is usually between 0.0 (far) and 1.0 (touching).
	# Change '0.5' to make it more or less strict!
	if closeness_factor > 0.7: 
		combo_meter = 1.0 
		_combo_pause_timer = 0.1 
	
	# We still give them points and a tiny multiplier increase for being vaguely close,
	# but the combo bar will keep draining unless they get closer to the wall!
	current_multiplier += (closeness_factor * delta * 1.5)
	current_multiplier = min(current_multiplier, max_multiplier)
		
	var base_points_per_second = 100.0 * closeness_factor
	unbanked_score += (base_points_per_second * current_multiplier) * delta
func add_trick_points(trick_name: String, base_points: int, mult_increase: float) -> void:
	combo_meter = 1.0 
	_combo_pause_timer = 0.1 # Pin it perfectly at 100% during tricks!
	
	current_multiplier += mult_increase
	current_multiplier = min(current_multiplier, max_multiplier)
	
	unbanked_score += (base_points * current_multiplier)
	style_event.emit(trick_name) 

func bank_score() -> void:
	if unbanked_score > 0:
		var final_addition = int(unbanked_score)
		total_score += final_addition
		score_updated.emit(total_score) 
		score_banked.emit(final_addition) 
		
	unbanked_score = 0.0
	current_multiplier = 1.0
	combo_meter = 0.0
	_combo_pause_timer = 0.0
	combo_updated.emit(0, 1.0, 0.0) 

func start_flying() -> void:
	is_flying = true
	
func stop_flying() -> void:
	is_flying = false
func stop_scoring() -> void:
	pass # We just need this here so the player script doesn't crash. The combo drain handles the rest!
func crash() -> void:
	is_flying = false
	bank_score() 

func prepare_for_restart() -> void:
	total_score = 0
	unbanked_score = 0.0
	current_multiplier = 1.0
	combo_meter = 0.0
	_combo_pause_timer = 0.0
	_passive_score_accumulator = 0.0
	is_flying = false
	score_updated.emit(total_score) 
	combo_updated.emit(0, 1.0, 0.0)
