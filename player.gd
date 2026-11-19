extends Node3D

signal paso_dado(corriendo: bool, pie_derecho: bool)
signal estado_aspiradora_cambiado(encendida: bool)

@export var velocidad_andar: float = 4.8
@export var velocidad_correr: float = 8.4
@export var velocidad_exhausto: float = 1.65
@export var fuerza_salto: float = 4.8
@export var sensibilidad_raton: float = 0.0025

@export var energia_max: float = 100.0
@export var coste_andar_seg: float = 1.6
@export var coste_correr_seg: float = 6.5
@export var coste_aspirar_seg: float = 3.2
@export var regen_reposo_seg: float = 1.2

var cuerpo: CharacterBody3D
var cabeza: Node3D
var camara: Camera3D

var energia: float = 100.0
var exhausto: bool = false
var dinero: int = 0

var _gravedad: float = 12.0
var _altura_ojos_base: float = 1.65
var _fase_paso: float = 0.0
var _pie_derecho: bool = true
var _estaba_en_suelo: bool = true
var _aspirando_anterior: bool = false

var _barra_energia: ProgressBar
var _label_energia: Label
var _label_dinero: Label

func _ready() -> void:
	energia = energia_max
	_construir_jugador()
	_crear_hud_jugador()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _construir_jugador() -> void:
	cuerpo = CharacterBody3D.new()
	cuerpo.name = "CuerpoJugador"
	cuerpo.position = Vector3(0.0, 0.25, 0.0)
	cuerpo.add_to_group("jugador")
	add_child(cuerpo)
	
	var col := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.35
	capsula.height = 1.8
	col.shape = capsula
	col.position = Vector3(0.0, 0.9, 0.0)
	cuerpo.add_child(col)
	
	cabeza = Node3D.new()
	cabeza.position = Vector3(0.0, _altura_ojos_base, 0.0)
	cuerpo.add_child(cabeza)
	
	camara = Camera3D.new()
	camara.fov = 75.0
	cabeza.add_child(camara)
	call_deferred("_activar_camara")

func _crear_hud_jugador() -> void:
	var capa := CanvasLayer.new()
	capa.name = "HUD_Jugador"
	add_child(capa)
	
	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	margen.grow_vertical = Control.GROW_DIRECTION_BEGIN
	margen.add_theme_constant_override("margin_left", 24)
	margen.add_theme_constant_override("margin_bottom", 22)
	capa.add_child(margen)
	
	var panel := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.06, 0.06, 0.06, 0.76)
	estilo.set_border_width_all(1)
	estilo.border_color = Color(0.75, 0.75, 0.75, 0.5)
	estilo.set_corner_radius_all(4)
	estilo.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", estilo)
	margen.add_child(panel)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	
	_label_dinero = Label.new()
	_label_dinero.text = "CASH: $0"
	_label_dinero.add_theme_font_size_override("font_size", 20)
	_label_dinero.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	vbox.add_child(_label_dinero)
	
	_label_energia = Label.new()
	_label_energia.text = "ENERGY: 100%"
	_label_energia.add_theme_font_size_override("font_size", 14)
	_label_energia.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(_label_energia)
	
	_barra_energia = ProgressBar.new()
	_barra_energia.custom_minimum_size = Vector2(210, 16)
	_barra_energia.max_value = energia_max
	_barra_energia.value = energia
	_barra_energia.show_percentage = false
	
	var bg_bar := StyleBoxFlat.new()
	bg_bar.bg_color = Color(0.15, 0.15, 0.15)
	var fill_bar := StyleBoxFlat.new()
	fill_bar.bg_color = Color(0.88, 0.88, 0.88)
	_barra_energia.add_theme_stylebox_override("background", bg_bar)
	_barra_energia.add_theme_stylebox_override("fill", fill_bar)
	vbox.add_child(_barra_energia)

func _activar_camara() -> void:
	if camara and camara.is_inside_tree():
		camara.make_current()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		cuerpo.rotate_y(-event.relative.x * sensibilidad_raton)
		cabeza.rotate_x(-event.relative.y * sensibilidad_raton)
		cabeza.rotation.x = clamp(cabeza.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))

func _physics_process(delta: float) -> void:
	if not cuerpo:
		return
	
	var en_suelo: bool = cuerpo.is_on_floor()
	
	if not en_suelo:
		cuerpo.velocity.y -= _gravedad * delta
	elif Input.is_key_pressed(KEY_SPACE) and not exhausto:
		cuerpo.velocity.y = fuerza_salto
		en_suelo = false
	
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0
	
	input_dir = input_dir.normalized()
	var moviendose: bool = input_dir != Vector2.ZERO
	var corriendo: bool = Input.is_key_pressed(KEY_SHIFT) and input_dir.y < 0.0 and not exhausto
	
	var velocidad_objetivo: float = velocidad_andar
	if exhausto:
		velocidad_objetivo = velocidad_exhausto
	elif corriendo:
		velocidad_objetivo = velocidad_correr
	
	var direccion: Vector3 = (cuerpo.transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	if direccion != Vector3.ZERO:
		cuerpo.velocity.x = direccion.x * velocidad_objetivo
		cuerpo.velocity.z = direccion.z * velocidad_objetivo
	else:
		cuerpo.velocity.x = move_toward(cuerpo.velocity.x, 0.0, velocidad_objetivo)
		cuerpo.velocity.z = move_toward(cuerpo.velocity.z, 0.0, velocidad_objetivo)
	
	cuerpo.move_and_slide()
	
	# Estado aspiradora y consumo de energía
	var quiere_aspirar: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	var aspirando: bool = quiere_aspirar and not exhausto
	if aspirando != _aspirando_anterior:
		_aspirando_anterior = aspirando
		estado_aspiradora_cambiado.emit(aspirando)
	
	_actualizar_energia(delta, moviendose, corriendo, aspirando)
	_procesar_pasos_y_cabeceo(delta, corriendo)
	_estaba_en_suelo = cuerpo.is_on_floor()

func _actualizar_energia(delta: float, moviendose: bool, corriendo: bool, aspirando: bool) -> void:
	var cambio: float = 0.0
	if corriendo:
		cambio -= coste_correr_seg * delta
	elif moviendose:
		cambio -= coste_andar_seg * delta
	else:
		# Si te quedas quieto recuperas un poquito de aliento
		cambio += regen_reposo_seg * delta
	
	if aspirando:
		cambio -= coste_aspirar_seg * delta
	
	energia = clamp(energia + cambio, 0.0, energia_max)
	
	if energia <= 0.01:
		exhausto = true
	elif exhausto and energia >= 15.0:
		# Sales del estado exhausto al recuperar al menos 15% de energía (o tomando un refresco)
		exhausto = false
	
	_refrescar_hud_jugador()

func _refrescar_hud_jugador() -> void:
	if _barra_energia:
		_barra_energia.value = energia
	if _label_energia:
		if exhausto:
			_label_energia.text = "ENERGY: %d%% (EXHAUSTED!)" % int(round(energia))
			_label_energia.add_theme_color_override("font_color", Color(0.95, 0.4, 0.4))
		else:
			_label_energia.text = "ENERGY: %d%%" % int(round(energia))
			_label_energia.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88))
	if _label_dinero:
		_label_dinero.text = "CASH: $%d" % dinero

func ganar_dinero(cantidad: int) -> void:
	dinero += cantidad
	_refrescar_hud_jugador()

func gastar_dinero(cantidad: int) -> bool:
	if dinero >= cantidad:
		dinero -= cantidad
		_refrescar_hud_jugador()
		return true
	return false

func recuperar_energia(cantidad: float) -> void:
	energia = clamp(energia + cantidad, 0.0, energia_max)
	if energia >= 15.0:
		exhausto = false
	_refrescar_hud_jugador()

func _procesar_pasos_y_cabeceo(delta: float, corriendo: bool) -> void:
	var vel_horizontal: float = Vector2(cuerpo.velocity.x, cuerpo.velocity.z).length()
	var en_suelo_ahora: bool = cuerpo.is_on_floor()
	
	if en_suelo_ahora and not _estaba_en_suelo:
		paso_dado.emit(true, _pie_derecho)
		_pie_derecho = not _pie_derecho
	
	if en_suelo_ahora and vel_horizontal > 0.5:
		var frecuencia: float = 2.85 if corriendo else (1.1 if exhausto else 1.85)
		var amplitud_y: float = 0.048 if corriendo else (0.015 if exhausto else 0.026)
		var amplitud_x: float = 0.025 if corriendo else 0.014
		
		var fase_anterior: float = _fase_paso
		_fase_paso += delta * frecuencia * TAU
		
		var ciclo_ant: int = int(floor(fase_anterior / PI))
		var ciclo_act: int = int(floor(_fase_paso / PI))
		if ciclo_act > ciclo_ant:
			paso_dado.emit(corriendo, _pie_derecho)
			_pie_derecho = not _pie_derecho
		
		var offset_y: float = -abs(sin(_fase_paso)) * amplitud_y
		var offset_x: float = cos(_fase_paso) * amplitud_x
		cabeza.position.y = lerp(cabeza.position.y, _altura_ojos_base + offset_y, delta * 14.0)
		cabeza.position.x = lerp(cabeza.position.x, offset_x, delta * 14.0)
	else:
		_fase_paso = 0.0
		cabeza.position.y = lerp(cabeza.position.y, _altura_ojos_base, delta * 10.0)
		cabeza.position.x = lerp(cabeza.position.x, 0.0, delta * 10.0)
