extends CanvasLayer

@onready var score_label = $ScoreLabel
@onready var close_call_label = $CloseCallLabel 
@onready var combo_bar = $ComboBar

var recent_styles: Array[String] = []

func _ready():
	ScoreManager.score_updated.connect(_on_score_updated)
	ScoreManager.combo_updated.connect(_on_combo_updated)
	ScoreManager.style_event.connect(_on_style_event)
	ScoreManager.score_banked.connect(_on_score_banked)
	
	close_call_label.text = ""
	combo_bar.value = 0.0
	combo_bar.visible = false # Hide the bar by default!
	combo_bar.step = 0.0 # Forces the bar to drain buttery smooth!
	score_label.text = "TOTAL: 0"

func _on_score_updated(new_score: int):
	score_label.text = "TOTAL: " + str(new_score)

func _on_combo_updated(unbanked: int, multiplier: float, meter_percent: float):
	combo_bar.value = meter_percent
	
	if unbanked > 0:
		combo_bar.visible = true # Reveal the bar while comboing
		
		var display_text = ""
		for style in recent_styles:
			display_text += style + "\n"
			
		display_text += "\n+" + str(unbanked) + "  |  x" + str(snapped(multiplier, 0.01))
		close_call_label.text = display_text
		close_call_label.modulate.a = 1.0

func _on_style_event(action_name: String):
	recent_styles.push_front("+ " + action_name)
	if recent_styles.size() > 4:
		recent_styles.pop_back()
		
	close_call_label.scale = Vector2(1.2, 1.2)
	var tween = create_tween()
	tween.tween_property(close_call_label, "scale", Vector2(1.0, 1.0), 0.2)

func _on_score_banked(amount: int):
	recent_styles.clear()
	combo_bar.visible = false # Hide the empty bar when cashing out!
	
	close_call_label.text = "BANKED!\n+" + str(amount)
	
	var tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(close_call_label, "modulate:a", 0.0, 0.4)
