extends Control

const LOADING_SCREEN = preload("res://loading_screen.tscn")

var is_restarting := false 

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


var _is_paused:bool = false:
	set(value):
		_is_paused = value
		get_tree().paused = _is_paused
		visible = _is_paused
		
		if _is_paused:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_is_paused = true
		get_viewport().set_input_as_handled()

func _on_resume_pressed() -> void:
	_is_paused = false

func _on_restart_pressed() -> void:
	_is_paused = false
	if is_restarting:
		return
	is_restarting = true
	get_tree().reload_current_scene()

func _on_options_pressed() -> void:
	get_tree().change_scene_to_file("res://Settings_Menu/settings_menu.tscn")

func _on_exit_to_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://Main_Menu/main_menu.tscn")
