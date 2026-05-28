extends CanvasLayer

@onready var score_label: Label = $score_label

func set_final_score(score: int) -> void:
	score_label.text = "Final Score: " + str(score)

# Função para ser chamada quando o jogador morrer
func _on_restart_pressed():
	get_tree().reload_current_scene()

# Conecte o sinal "pressed" do botão "Tentar Novamente" aqui
func _on_select_mode_pressed():
	get_tree().change_scene_to_file("res://selecao_de_modo.tscn")

# Conecte o sinal "pressed" do botão "Sair" aqui
func _on_exit_to_menu_pressed() -> void:
	#Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://Main_Menu/main_menu.tscn")
