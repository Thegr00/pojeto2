class_name SettingsMenu
extends Control

@onready var exit_button: Button = $MarginContainer/VBoxContainer/Exit_button

signal exit_options_menu

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	exit_button.button_down.connect(on_exit_pressed)

func on_exit_pressed() -> void:
	exit_options_menu.emit()
