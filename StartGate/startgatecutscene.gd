extends Node3D

@export var target_entity: Node3D 
@export var is_cutscene: bool = false # Add a toggle for the inspector!

@onready var portal_graphic = $PortalGraphic

func _ready():
	#Only play automatically if we are in a normal level!
	if not is_cutscene:
		play_portal_intro_cutscene()
	
func play_portal_intro_cutscene():
	if portal_graphic:
		portal_graphic.scale = Vector3(0.01, 0.1, 1.0) 
	if not portal_graphic: return
	
	# 1. DRAW THE SLASH
	var slice_tween = create_tween()
	slice_tween.tween_property(portal_graphic, "scale", Vector3(0.01, 1.7, 1.0), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await slice_tween.finished
	await get_tree().create_timer(0.5).timeout
	
	# 2. POP IT OPEN
	var open_tween = create_tween()
	open_tween.tween_property(portal_graphic, "scale", Vector3(1.5, 1.7, 1.0), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await open_tween.finished
	
	# 3. LEAVE IT OPEN FOR A BIT
	await get_tree().create_timer(1.5).timeout
	
	# 4. SNAP SHUT TO A SLASH
	var close_tween = create_tween()
	# Notice we go back to X = 0.01, but keep Y = 3.5
	close_tween.tween_property(portal_graphic, "scale", Vector3(0.01, 1.7, 1.0), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await close_tween.finished
	
	# Optional: Wait a tiny fraction of a second so the player actually sees the slash
	await get_tree().create_timer(0.2).timeout
	
	# 5. SHRINK THE SLASH AWAY
	var shrink_tween = create_tween()
	shrink_tween.tween_property(portal_graphic, "scale", Vector3(0.01, 0.001, 1.0), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await shrink_tween.finished
	
	# 6. GIVE CONTROL BACK (If you add code for this later!)
