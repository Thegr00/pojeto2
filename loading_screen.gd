extends CanvasLayer

@export var world_manager: Node

# --- PATTERN SETTINGS ---
@export var pattern_size: int = 3 
@export var pattern_gap: float = -35

# --- WAVE SETTINGS ---
@export var wave_offset: float = 3.14 

var sprites: Array[TextureRect] = []
var initial_ys: Dictionary = {}
var wrap_distance := 0.0

var is_loading := true
var initial_queue_filled := false
var screen_width := 0.0

const SPEED := 400.0 
const BOUNCE_SPEED := 10.0 
const BOUNCE_HEIGHT := 3.0 


func _ready() -> void:
	
	self.layer = 128
	
	if world_manager != null and world_manager.player != null:
		world_manager.player.process_mode = Node.PROCESS_MODE_DISABLED
		
	screen_width = get_viewport().get_visible_rect().size.x
	
	# --- THE FIX: Start fully covering the screen! ---
	# We removed the entrance Tween because the old scene will handle it.
	self.offset = Vector2(0, 0)
	
	_find_all_sprites(self)
	
	if sprites.size() > 0:
		_setup_pattern()


func _input(event: InputEvent) -> void:
	if is_loading:
		get_viewport().set_input_as_handled()




func _find_all_sprites(node: Node) -> void:
	for child in node.get_children():
		if child is TextureRect:
			sprites.append(child)
		_find_all_sprites(child)

func _setup_pattern() -> void:
	if sprites.size() < pattern_size:
		return 
		
	var first_sprite = sprites[0]
	var last_pattern_sprite = sprites[pattern_size - 1]
	
	var base_pattern_width = (last_pattern_sprite.position.x + last_pattern_sprite.size.x) - first_sprite.position.x
	var total_block_width = base_pattern_width + pattern_gap
	
	for i in range(sprites.size()):
		var base_index = i % pattern_size 
		var block_index = i / pattern_size 
		
		sprites[i].position.y = sprites[base_index].position.y
		initial_ys[sprites[i]] = sprites[i].position.y
		
		sprites[i].position.x = sprites[base_index].position.x + (total_block_width * block_index)
		
	var total_blocks = ceil(float(sprites.size()) / float(pattern_size))
	wrap_distance = total_block_width * total_blocks

func _process(delta: float) -> void:
	var time = Time.get_ticks_msec() / 1000.0

	for i in range(sprites.size()):
		var sprite = sprites[i]
		sprite.position.x += SPEED * delta 
		
		sprite.position.y = initial_ys[sprite] + sin((time * BOUNCE_SPEED) + (i * wave_offset)) * BOUNCE_HEIGHT
		
		if sprite.position.x > screen_width + 200: 
			sprite.position.x -= wrap_distance

	if not is_loading:
		return

	if world_manager != null:
		var queue_size = world_manager.chunk_queue.size()
		if queue_size > 0:
			initial_queue_filled = true
		
		if initial_queue_filled and queue_size <= 10:
			_finish_loading()

func _finish_loading() -> void:
	is_loading = false
	
	if world_manager != null and world_manager.player != null:
		world_manager.player.process_mode = Node.PROCESS_MODE_INHERIT
	
	# Exit swipe: Animate from the center to off-screen right
	var tween = create_tween()
	tween.tween_property(self, "offset", Vector2(screen_width, 0), 0.4)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)
	
	tween.tween_callback(queue_free)
