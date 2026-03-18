extends CanvasLayer

# CRITICAL: We need this signal so the 3D game knows when to resume!
signal dialogue_finished 

@onready var texto: RichTextLabel = $Panel/Texto
@onready var diabo_anjo: TextureRect = $Control/Diabo_anjo
@onready var fade_screen = $Fadescreen

# A simple array of dictionaries to hold our cutscene data
var dialogue_data = []
var current_line_index = 0
var is_active = false

func _ready():
	# Hide the UI by default when the game starts
	hide()

# Call this function from your 3D world
func start_dialogue(new_dialogue_data):
	dialogue_data = new_dialogue_data
	current_line_index = 0
	is_active = true
	show()
	show_current_line()

func show_current_line():
	if current_line_index < dialogue_data.size():
		var line = dialogue_data[current_line_index]
		
		# FIXED: Now using 'texto' instead of 'dialogue_text'
		texto.text = line["name"] + ":\n" + line["text"]
		
		# FIXED: Now using 'diabo_anjo' instead of 'portrait'
		diabo_anjo.texture = load(line["portrait_path"])
	else:
		end_dialogue()

func end_dialogue():
	is_active = false
	hide()
	# CRITICAL: This tells the 3D script that it's safe to clear the black screen!
	dialogue_finished.emit()

func _input(event):
	# If dialogue is active and the player presses "Accept" (usually Enter, Space, or A button)
	if is_active and event.is_action_pressed("ui_accept"):
		current_line_index += 1
		show_current_line()

# FIXED: Now using 'fade_screen' instead of 'black_screen'
func cut_to_black():
	fade_screen.modulate.a = 1.0 
	fade_screen.show()

# FIXED: Now using 'fade_screen' instead of 'black_screen'
func clear_screen():
	fade_screen.hide()
