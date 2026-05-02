extends Node3D

@export var target_entity: Node3D 
@export var is_cutscene: bool = false # Add a toggle for the inspector!

@onready var cinematic_cam = $CinematicCam 
@onready var portal_graphic = $PortalGraphic

func _ready():
	#Only play automatically if we are in a normal level!
	if not is_cutscene:
		play_portal_intro()


func play_portal_intro():
	# 1. FOOLPROOF TARGET DETECTION
	if not target_entity:
		# Explicitly search for your exact node name!
		target_entity = get_tree().current_scene.find_child("mangas3p", true, false)
		
	# 2. Freeze the Player
	if target_entity and target_entity.has_method("prepare_for_spawn"):
		target_entity.prepare_for_spawn()

	# 3. Setup Cinematic Camera
	# Only let the portal control the camera in normal levels!
	if cinematic_cam and not is_cutscene:
		cinematic_cam.make_current()

	if portal_graphic:
		portal_graphic.scale = Vector3(0.01, 0.1, 1.0) 

	# 4. Wait for Loading Screen
	var root = get_tree().root
	var loading_screen = root.find_child("LoadingScreen", true, false)
	if loading_screen:
		while is_instance_valid(loading_screen) and loading_screen.visible:
			await get_tree().process_frame

	if not portal_graphic: return

	# I DELETED THE STRAY CAMERA HIJACK LINE THAT WAS HERE!
	await get_tree().create_timer(0.2).timeout
	
	# 5. DRAW THE SLASH
	var slice_tween = create_tween()
	slice_tween.tween_property(portal_graphic, "scale", Vector3(0.01, 4.0, 1.0), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await slice_tween.finished
	await get_tree().create_timer(0.2).timeout
	
	# 6. POP IT OPEN
	var open_tween = create_tween()
	open_tween.tween_property(portal_graphic, "scale", Vector3(3.0, 4.0, 4.0), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await open_tween.finished
	
	# 7. SPEW THE PLAYER OUT
	if target_entity and target_entity.has_method("spew_out"):
		target_entity.visible = true
		target_entity.spew_out(global_transform)

	await get_tree().create_timer(0.2).timeout
	
	# 8. SHRINK THE PORTAL
	var close_tween = create_tween()
	close_tween.tween_property(portal_graphic, "scale", Vector3(0.01, 0.001, 1.0), 0.5).set_trans(Tween.TRANS_SINE)
	
	# 9. GIVE CONTROL BACK
	if target_entity and target_entity.has_method("finish_spawn"):
		target_entity.finish_spawn()
