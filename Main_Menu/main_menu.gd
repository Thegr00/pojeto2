class_name MainMenu
extends Control

@onready var start_button: Button = $MarginContainer/VBoxContainer/VBoxContainer/Start_button
@onready var opt_button: Button = $MarginContainer/VBoxContainer/VBoxContainer/Opt_button
@onready var exit_button: Button = $MarginContainer/VBoxContainer/VBoxContainer/Exit_button
@onready var settings_menu: SettingsMenu = $Settings_menu
@onready var margin_container: MarginContainer = $MarginContainer
@onready var selecao_de_modo: Control = $SelecaoDeModo

@onready var start_level = preload("res://Generation/terrain_manager.tscn") as PackedScene

func _ready() -> void:
	# Primeiro configuramos os pivots (esperando apenas 1 frame para o layout assentar)
	await setup_button_pivots()
	# Só depois ligamos os sinais, garantindo que tudo está pronto
	handle_signals()

func handle_signals() -> void:
	# Alterado para 'pressed', que é o sinal padrão e mais seguro para botões UI
	start_button.pressed.connect(on_start_pressed)
	opt_button.pressed.connect(on_options_pressed)
	exit_button.pressed.connect(on_exit_pressed)
	settings_menu.exit_options_menu.connect(on_exit_options_menu)

	var buttons: Array[Button] = [start_button, opt_button, exit_button]
	
	for btn in buttons:
		btn.mouse_entered.connect(_on_button_hover.bind(btn))
		btn.mouse_exited.connect(_on_button_exit.bind(btn))

func setup_button_pivots() -> void:
	# Espera um único frame para o Godot calcular os tamanhos reais dos containers
	await get_tree().process_frame 
	
	var buttons: Array[Button] = [start_button, opt_button, exit_button]
	for btn in buttons:
		btn.pivot_offset = btn.size / 2.0

func _on_button_hover(btn: Button) -> void:
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Aumenta o tamanho em 15% (funciona bem se o pivot estiver no centro)
	tween.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.15)
	# Aumenta o brilho do botão para dar feedback visual sem mover o botão do sítio
	tween.parallel().tween_property(btn, "modulate", Color(1.3, 1.3, 1.3, 1.0), 0.15)

func _on_button_exit(btn: Button) -> void:
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15)
	tween.parallel().tween_property(btn, "modulate", Color.WHITE, 0.15)

func on_start_pressed() -> void:
	margin_container.visible = false
	selecao_de_modo.set_process(true)
	selecao_de_modo.visible = true

func on_options_pressed() -> void:
	margin_container.visible = false
	settings_menu.set_process(true)
	settings_menu.visible = true

func on_exit_pressed() -> void:
	get_tree().quit()

func on_exit_options_menu() -> void:
	margin_container.visible = true
	settings_menu.visible = false

#func handle_signals() -> void:
	#start_button.button_down.connect(on_start_pressed)
	#opt_button.button_down.connect(on_options_pressed)
	#exit_button.button_down.connect(on_exit_pressed)
	#settings_menu.exit_options_menu.connect(on_exit_options_menu)
