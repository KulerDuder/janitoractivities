extends Node3D

signal zona_cambiada(nombre_zona: String, es_segura: bool)

var zona_actual: String = "Outside"
var jugador_a_salvo: bool = false

var _zonas_activas: Array[Dictionary] = []
var _label_zona: Label
var _label_estado: Label

func _ready() -> void:
	_crear_hud_zona()
	call_deferred("_construir_todas_las_zonas")

func _crear_hud_zona() -> void:
	var capa := CanvasLayer.new()
	capa.name = "HUD_Zonas"
	add_child(capa)
	
	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 24)
	margen.add_theme_constant_override("margin_top", 20)
	capa.add_child(margen)
	
	var panel := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.06, 0.06, 0.06, 0.72)
	estilo.set_border_width_all(1)
	estilo.border_color = Color(0.75, 0.75, 0.75, 0.5)
	estilo.set_corner_radius_all(4)
	estilo.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", estilo)
	margen.add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	
	_label_zona = Label.new()
	_label_zona.text = "Outside"
	_label_zona.add_theme_font_size_override("font_size", 22)
	_label_zona.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	vbox.add_child(_label_zona)
	
	_label_estado = Label.new()
	_label_estado.text = "UNSAFE"
	_label_estado.add_theme_font_size_override("font_size", 14)
	_label_estado.add_theme_color_override("font_color", Color(0.85, 0.35, 0.35))
	vbox.add_child(_label_estado)

func _construir_todas_las_zonas() -> void:
	var mapas := get_tree().get_nodes_in_group("mapa_instituto")
	if mapas.is_empty():
		push_warning("zonas.gd: No se encontró 'mapa_instituto'")
		return
	var mapa: Node = mapas[0]
	
	for p: Dictionary in mapa.pasillos:
		_registrar_zona(p["nombre"], p["centro"], p["tamano"], p["segura"], 0)
	
	for hab: Dictionary in mapa.habitaciones:
		_registrar_zona(hab["nombre"], hab["centro"], hab["tamano"], hab["segura"], 1)

func _registrar_zona(nombre: String, centro: Vector3, tamano: Vector3, es_segura: bool, prioridad: int) -> void:
	var area := Area3D.new()
	area.name = "Zona_" + nombre.replace(" ", "_")
	area.position = centro
	area.monitoring = true
	area.monitorable = false
	
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = tamano
	col.shape = shape
	area.add_child(col)
	add_child(area)
	
	var info := {
		"area": area,
		"nombre": nombre,
		"segura": es_segura,
		"prioridad": prioridad
	}
	
	area.body_entered.connect(func(body: Node3D) -> void:
		if body.is_in_group("jugador"):
			_entrar_en_zona(info)
	)
	area.body_exited.connect(func(body: Node3D) -> void:
		if body.is_in_group("jugador"):
			_salir_de_zona(info)
	)

func _entrar_en_zona(info: Dictionary) -> void:
	if not _zonas_activas.has(info):
		_zonas_activas.append(info)
	_actualizar_zona_actual()

func _salir_de_zona(info: Dictionary) -> void:
	_zonas_activas.erase(info)
	_actualizar_zona_actual()

func _actualizar_zona_actual() -> void:
	if _zonas_activas.is_empty():
		zona_actual = "Outside"
		jugador_a_salvo = false
	else:
		var elegida: Dictionary = _zonas_activas[0]
		for z: Dictionary in _zonas_activas:
			if z["prioridad"] >= elegida["prioridad"]:
				elegida = z
		zona_actual = elegida["nombre"]
		jugador_a_salvo = elegida["segura"]
	
	_refrescar_hud()
	zona_cambiada.emit(zona_actual, jugador_a_salvo)

func _refrescar_hud() -> void:
	if not _label_zona or not _label_estado:
		return
	_label_zona.text = zona_actual
	if jugador_a_salvo:
		_label_estado.text = "YOU ARE SAFE"
		_label_estado.add_theme_color_override("font_color", Color(0.45, 0.90, 0.50))
	else:
		_label_estado.text = "NOT SAFE"
		_label_estado.add_theme_color_override("font_color", Color(0.85, 0.35, 0.35))
