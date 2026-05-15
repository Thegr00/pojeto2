extends CanvasLayer

# Pega a referência do nó que criamos para agrupar o fundo e o texto
@onready var container = $ContainerFade 

func mostrar_death_scene():
	# Garante que a tela principal está visível
	visible = true
	
	# Define a transparência do container para 0 (invisível)
	container.modulate = Color(1, 1, 1, 0)
	
	# Cria o Tween para animar o container até 1 (totalmente visível)
	var tween = create_tween()
	tween.tween_property(container, "modulate", Color(1, 1, 1, 1), 1.5)
