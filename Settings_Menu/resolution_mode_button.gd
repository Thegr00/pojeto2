extends Control

@onready var option_button: OptionButton = $HBoxContainer/OptionButton

const RESOLUTION_DICTIONARY : Dictionary = {
	"1152 x 648" : Vector2i(1152, 648),
	"1280 x 720" : Vector2i(1280, 720),
	"1920 x 1080" : Vector2i(1920, 1080)
}

func _ready():
	add_resolution_items()
	option_button.item_selected.connect(on_resolution_selected)

func add_resolution_items() -> void:
	for resolution_size_text in RESOLUTION_DICTIONARY:
		option_button.add_item(resolution_size_text)

func on_resolution_selected(index : int) -> void:
	var resolution_key = option_button.get_item_text(index)
	
	var target_size = RESOLUTION_DICTIONARY[resolution_key]
	
	DisplayServer.window_set_size(target_size)
	
	center_window()

func center_window():
	var screen_center = DisplayServer.screen_get_position() + DisplayServer.screen_get_size() / 2
	var window_size = DisplayServer.window_get_size()
	DisplayServer.window_set_position(screen_center - window_size / 2)
