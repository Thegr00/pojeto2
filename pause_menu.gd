extends Control

const LOADING_SCREEN = preload("res://loading_screen.tscn")

@onready var settings_menu: SettingsMenu = $Settings_menu
@onready var v_box_container: VBoxContainer = $VBoxContainer


var is_restarting := false 

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	settings_menu.exit_options_menu.connect(_on_settings_exit)
	
	settings_menu.hide()
	v_box_container.show()


var _is_paused:bool = false:
	set(value):
		_is_paused = value
		
		var tree = get_tree()
		if tree:
			tree.paused = _is_paused
		
		visible = _is_paused
		
		if _is_paused:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		# CHECK: If the loading screen is present, do nothing!
		if get_tree().root.find_child("LoadingScreen", true, false):
			return 
			
		if _is_paused:
			get_viewport().set_input_as_handled()
			return
			
		_is_paused = !_is_paused
		get_viewport().set_input_as_handled()

func _on_resume_pressed() -> void:
	_is_paused = false

func _on_restart_pressed() -> void:
	if is_restarting:
		return
	is_restarting = true
	
	_is_paused = false # Unpause the engine
	get_tree().paused = false # Safety force-unpause
	
	get_tree().reload_current_scene()

func _on_options_pressed() -> void:
	v_box_container.hide()
	settings_menu.show()

func _on_settings_exit() -> void:
	settings_menu.hide()
	v_box_container.show()

func _on_exit_to_menu_pressed() -> void:
	_is_paused = false 
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://Main_Menu/main_menu.tscn")
