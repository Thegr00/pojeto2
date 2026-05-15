class_name MainMenu
extends Control

@onready var start_button: Button = $MarginContainer/HBoxContainer/VBoxContainer/Start_button
@onready var opt_button: Button = $MarginContainer/HBoxContainer/VBoxContainer/Opt_button
@onready var exit_button: Button = $MarginContainer/HBoxContainer/VBoxContainer/Exit_button
@onready var settings_menu: SettingsMenu = $Settings_menu
@onready var margin_container: MarginContainer = $MarginContainer


@onready var start_level = preload("res://Generation/terrain_manager.tscn") as PackedScene


#func _ready():
	#handle_signals()


func _ready():
	# É boa prática definir o pivot de escala para o centro dos botões
	# Para que eles cresçam a partir do meio e não do canto superior esquerdo
	setup_button_pivots()
	handle_signals()

# ... [As tuas funções on_start_pressed, etc. continuam aqui] ...

func handle_signals() -> void:
	# 1. Os teus sinais originais de clique
	start_button.button_down.connect(on_start_pressed)
	opt_button.button_down.connect(on_options_pressed)
	exit_button.button_down.connect(on_exit_pressed)
	settings_menu.exit_options_menu.connect(on_exit_options_menu)
	
	# 2. NOVA PARTE: Sinais de Hover (passar o rato)
	# Colocamos os botões num Array para aplicar o efeito a todos de uma vez
	var buttons: Array[Button] = [start_button, opt_button, exit_button]
	
	for btn in buttons:
		# O .bind(btn) é a magia que diz à função qual botão acionou o efeito
		btn.mouse_entered.connect(_on_button_hover.bind(btn))
		btn.mouse_exited.connect(_on_button_exit.bind(btn))

# --- NOVAS FUNÇÕES DE ANIMAÇÃO ---

func setup_button_pivots() -> void:
	# Opcional mas recomendado: Centraliza o ponto de ancoragem (pivot) de cada botão.
	# Isto faz com que, ao aumentar o "scale", o botão cresça a partir do centro.
	var buttons: Array[Button] = [start_button, opt_button, exit_button]
	for btn in buttons:
		# O Godot precisa de um frame para calcular os tamanhos dentro dos Containers
		await get_tree().process_frame 
		btn.pivot_offset = btn.size / 2.0

func _on_button_hover(btn: Button) -> void:
	# Cria uma animação suave (SINE) que desacelera no final (EASE_OUT)
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Aumenta o tamanho em 10%
	tween.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.15)
	
	# Efeito Bónus: Usa .parallel() para que estas ações aconteçam ao mesmo tempo
	# Isto move o botão ligeiramente para a direita (opcional, podes apagar se não gostares)
	tween.parallel().tween_property(btn, "position:x", 15.0, 0.15)
	# Isto aumenta o brilho do botão para lhe dar destaque
	tween.parallel().tween_property(btn, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.15)

func _on_button_exit(btn: Button) -> void:
	# Animação suave para voltar ao normal
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15)
	tween.parallel().tween_property(btn, "position:x", 0.0, 0.15)
	tween.parallel().tween_property(btn, "modulate", Color.WHITE, 0.15)


func on_start_pressed() -> void:
	get_tree().change_scene_to_packed(start_level)

func on_options_pressed() -> void:
	margin_container.visible = false
	settings_menu.set_process(true)
	settings_menu.visible = true


func on_exit_pressed() -> void:
	get_tree().quit()

func on_exit_options_menu() -> void:
	margin_container.visible = true
	settings_menu.visible = false



##func handle_signals() -> void:
	#start_button.button_down.connect(on_start_pressed)
	#opt_button.button_down.connect(on_options_pressed)
	#exit_button.button_down.connect(on_exit_pressed)
	#settings_menu.exit_options_menu.connect(on_exit_options_menu)
