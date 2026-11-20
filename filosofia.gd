extends Node3D

signal pregunta_respondida(indice: int, texto: String, respuesta_si: bool)

@export_file("*.txt") var ruta_archivo: String = "res://philosophy.txt"
@export var texto_boton_si: String = "SÍ"
@export var texto_boton_no: String = "NO"

# Registro público de las decisiones del jugador para usar más adelante
var respuestas_jugador: Array[Dictionary] = []

var _preguntas: Array[String] = []
var _umbrales_pct: Array[float] = []
var _indice_actual: int = 0
var _mostrando: bool = false
var _gestor_suciedad: Node = null

var _capa_ui: CanvasLayer
var _panel_fondo: ColorRect
var _label_titulo: Label
var _label_texto: Label
var _boton_si: Button
var _boton_no: Button

func _ready() -> void:
	add_to_group("gestor_filosofia")
	_cargar_preguntas_txt()
	_crear_interfaz_modal()
	call_deferred("_vincular_y_calcular_umbrales")

func _cargar_preguntas_txt() -> void:
	_preguntas.clear()
	if not FileAccess.file_exists(ruta_archivo):
		push_warning("filosofia.gd: No se encontró el archivo " + ruta_archivo)
		return
	
	var f := FileAccess.open(ruta_archivo, FileAccess.READ)
	if not f:
		return
	var contenido: String = f.get_as_text().replace("\r\n", "\n").strip_edges()
	f.close()
	
	if contenido.is_empty():
		return
	
	# Separamos por párrafos (uno o más saltos de línea dobles)
	var bloques: PackedStringArray = contenido.split("\n\n", false)
	for bloque: String in bloques:
		var limpio: String = bloque.strip_edges()
		if not limpio.is_empty():
			_preguntas.append(limpio)

func _vincular_y_calcular_umbrales() -> void:
	_umbrales_pct.clear()
	if _preguntas.is_empty():
		return
	
	var gestores := get_tree().get_nodes_in_group("gestor_suciedad")
	if not gestores.is_empty():
		_gestor_suciedad = gestores[0]
	
	var meta_pct: float = 100.0
	if _gestor_suciedad and "porcentaje_para_final" in _gestor_suciedad:
		meta_pct = float(_gestor_suciedad.porcentaje_para_final)
	
	# Distribuimos las preguntas en intervalos regulares antes de alcanzar la meta
	var total: int = _preguntas.size()
	var paso: float = meta_pct / float(total + 1)
	for i: int in range(total):
		_umbrales_pct.append(paso * float(i + 1))

func _process(_delta: float) -> void:
	if _mostrando or _indice_actual >= _preguntas.size() or _indice_actual >= _umbrales_pct.size():
		return
	
	if not _gestor_suciedad or not is_instance_valid(_gestor_suciedad):
		var gestores := get_tree().get_nodes_in_group("gestor_suciedad")
		if gestores.is_empty():
			return
		_gestor_suciedad = gestores[0]
	
	var total: int = _gestor_suciedad.get("_total_activos")
	var recogidos: int = _gestor_suciedad.get("_recogidos")
	if total > 0:
		var pct: float = (float(recogidos) / float(total)) * 100.0
		if pct >= _umbrales_pct[_indice_actual]:
			_abrir_pregunta(_indice_actual)

func _abrir_pregunta(idx: int) -> void:
	_mostrando = true
	_label_titulo.text = "THOUGHT #%d" % (idx + 1)
	_label_texto.text = _preguntas[idx]
	_panel_fondo.visible = true
	
	# Pausamos la partida y liberamos el ratón para responder con tranquilidad
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_boton_si.grab_focus()

func _responder(es_si: bool) -> void:
	if not _mostrando:
		return
	
	var texto_actual: String = _preguntas[_indice_actual]
	respuestas_jugador.append({
		"indice": _indice_actual,
		"pregunta": texto_actual,
		"respuesta_si": es_si,
		"respuesta_texto": texto_boton_si if es_si else texto_boton_no
	})
	pregunta_respondida.emit(_indice_actual, texto_actual, es_si)
	
	_indice_actual += 1
	_mostrando = false
	_panel_fondo.visible = false
	
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _crear_interfaz_modal() -> void:
	_capa_ui = CanvasLayer.new()
	_capa_ui.name = "HUD_Filosofia"
	_capa_ui.layer = 12 # Por encima del filtro de cine y de todos los HUD
	_capa_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_capa_ui)
	
	_panel_fondo = ColorRect.new()
	_panel_fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_fondo.color = Color(0.0, 0.0, 0.0, 0.72)
	_panel_fondo.visible = false
	_capa_ui.add_child(_panel_fondo)
	
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_fondo.add_child(center)
	
	var caja := PanelContainer.new()
	caja.custom_minimum_size = Vector2(620, 0)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.05, 0.05, 0.05, 0.96)
	estilo.set_border_width_all(2)
	estilo.border_color = Color(0.92, 0.92, 0.92, 0.9)
	estilo.set_corner_radius_all(4)
	estilo.set_content_margin_all(28)
	caja.add_theme_stylebox_override("panel", estilo)
	center.add_child(caja)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 22)
	caja.add_child(vbox)
	
	_label_titulo = Label.new()
	_label_titulo.text = "THOUGHT #1"
	_label_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_titulo.add_theme_font_size_override("font_size", 16)
	_label_titulo.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	vbox.add_child(_label_titulo)
	
	_label_texto = Label.new()
	_label_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_texto.add_theme_font_size_override("font_size", 22)
	_label_texto.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	vbox.add_child(_label_texto)
	
	var hbox_botones := HBoxContainer.new()
	hbox_botones.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_botones.add_theme_constant_override("separation", 36)
	vbox.add_child(hbox_botones)
	
	_boton_si = _crear_boton_opcion(texto_boton_si)
	_boton_si.pressed.connect(func() -> void: _responder(true))
	hbox_botones.add_child(_boton_si)
	
	_boton_no = _crear_boton_opcion(texto_boton_no)
	_boton_no.pressed.connect(func() -> void: _responder(false))
	hbox_botones.add_child(_boton_no)

func _crear_boton_opcion(etiqueta: String) -> Button:
	var btn := Button.new()
	btn.text = "   " + etiqueta + "   "
	btn.custom_minimum_size = Vector2(140, 46)
	btn.add_theme_font_size_override("font_size", 20)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var st_norm := StyleBoxFlat.new()
	st_norm.bg_color = Color(0.10, 0.10, 0.10)
	st_norm.set_border_width_all(2)
	st_norm.border_color = Color(0.88, 0.88, 0.88)
	
	var st_hover := st_norm.duplicate()
	st_hover.bg_color = Color(0.92, 0.92, 0.92)
	
	btn.add_theme_stylebox_override("normal", st_norm)
	btn.add_theme_stylebox_override("hover", st_hover)
	btn.add_theme_stylebox_override("focus", st_hover)
	btn.add_theme_stylebox_override("pressed", st_hover)
	
	btn.add_theme_color_override("font_color", Color(0.94, 0.94, 0.94))
	btn.add_theme_color_override("font_hover_color", Color(0.05, 0.05, 0.05))
	btn.add_theme_color_override("font_focus_color", Color(0.05, 0.05, 0.05))
	btn.add_theme_color_override("font_pressed_color", Color(0.05, 0.05, 0.05))
	return btn
