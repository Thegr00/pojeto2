extends Button # Or "extends Button" depending on what node you used

@export var target_scale: Vector2 = Vector2(1.1, 1.1) # 10% bigger
@export var default_scale: Vector2 = Vector2(1.0, 1.0)
@export var duration: float = 0.1 # Speed of the animation

func _ready() -> void:
	# Connect the hover signals to our functions
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	# Smoothly scale up
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", target_scale, duration)

func _on_mouse_exited() -> void:
	# Smoothly scale back down
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", default_scale, duration)
