extends Node3D

@export var precio_bebida: int = 15
@export var energia_recuperada: float = 55.0

const SAMPLE_RATE: int = 22050

var _jugador_cerca: bool = false
var _player_ref: Node = null
var _label_prompt: Label
var _lata_dispensada: MeshInstance3D
var _tiempo_anim_lata: float = 0.0
var _audio_maquina: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 24680
	# Ubicada dentro de la Janitor Office (X de -11 a -4, Z de -26 a -12), pegada a la pared izquierda
	position = Vector3(-10.1, 0.52, -16.5)
	rotation_degrees.y = 90.0
	
	_construir_modelo_maquina()
	_crear_area_interaccion()
	_crear_hud_interaccion()
	_preparar_audio_lata()

func _crear_mat(color: Color, roughness: float = 0.6, emision: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	if emision > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emision
	return mat

func _crear_pieza(tam: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = tam
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi

func _construir_modelo_maquina() -> void:
	var mat_cuerpo := _crear_mat(Color(0.22, 0.24, 0.28), 0.55)
	var mat_borde := _crear_mat(Color(0.12, 0.12, 0.14), 0.7)
	var mat_cristal := _crear_mat(Color(0.88, 0.90, 0.86), 0.25, 0.95)
	var mat_hueco := _crear_mat(Color(0.05, 0.05, 0.05), 0.9)
	var mat_lata := _crear_mat(Color(0.75, 0.75, 0.78), 0.3)
	
	# Cuerpo principal y colisión física
	_crear_pieza(Vector3(1.15, 2.15, 0.85), Vector3(0.0, 1.075, 0.0), mat_cuerpo)
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.15, 2.15, 0.85)
	col.shape = shape
	col.position = Vector3(0.0, 1.075, 0.0)
	sb.add_child(col)
	add_child(sb)
	
	# Cartel superior luminoso ("SODA")
	_crear_pieza(Vector3(0.95, 0.35, 0.06), Vector3(0.0, 1.85, 0.43), mat_cristal)
	
	# Escaparate iluminado con filas de latas
	_crear_pieza(Vector3(0.68, 0.95, 0.05), Vector3(-0.14, 1.12, 0.43), mat_cristal)
	for fila: int in range(3):
		for col_idx: int in range(4):
			var lx: float = -0.36 + float(col_idx) * 0.14
			var ly: float = 0.82 + float(fila) * 0.28
			_crear_pieza(Vector3(0.08, 0.14, 0.04), Vector3(lx, ly, 0.445), mat_lata)
	
	# Panel de botones y ranura de monedas
	_crear_pieza(Vector3(0.24, 0.75, 0.06), Vector3(0.38, 1.15, 0.43), mat_borde)
	for b: int in range(4):
		_crear_pieza(Vector3(0.10, 0.05, 0.03), Vector3(0.38, 1.35 - float(b) * 0.11, 0.46), mat_cristal)
	
	# Trampilla inferior dispensadora
	_crear_pieza(Vector3(0.75, 0.26, 0.08), Vector3(-0.08, 0.35, 0.42), mat_hueco)
	
	# Lata que salta al comprar
	_lata_dispensada = _crear_pieza(Vector3(0.09, 0.16, 0.09), Vector3(-0.08, 0.32, 0.48), mat_lata)
	_lata_dispensada.visible = false

func _crear_area_interaccion() -> void:
	var area := Area3D.new()
	area.name = "AreaCompra"
	area.position = Vector3(0.0, 1.0, 1.1)
	
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 2.2, 2.2)
	col.shape = shape
	area.add_child(col)
	add_child(area)
	
	area.body_entered.connect(func(body: Node3D) -> void:
		if body.is_in_group("jugador"):
			_jugador_cerca = true
			_player_ref = body.get_parent()
			_actualizar_prompt()
	)
	area.body_exited.connect(func(body: Node3D) -> void:
		if body.is_in_group("jugador"):
			_jugador_cerca = false
			_actualizar_prompt()
	)

func _crear_hud_interaccion() -> void:
	var capa := CanvasLayer.new()
	capa.name = "HUD_Maquina"
	add_child(capa)
	
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(center)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 180)
	center.add_child(margin)
	
	_label_prompt = Label.new()
	_label_prompt.visible = false
	_label_prompt.add_theme_font_size_override("font_size", 22)
	_label_prompt.add_theme_color_override("font_color", Color(0.96, 0.96, 0.96))
	_label_prompt.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	_label_prompt.add_theme_constant_override("shadow_offset_x", 2)
	_label_prompt.add_theme_constant_override("shadow_offset_y", 2)
	margin.add_child(_label_prompt)

func _actualizar_prompt() -> void:
	if not _label_prompt:
		return
	if not _jugador_cerca:
		_label_prompt.visible = false
		return
	
	_label_prompt.visible = true
	var dinero_actual: int = 0
	if _player_ref and "dinero" in _player_ref:
		dinero_actual = _player_ref.dinero
	
	if dinero_actual >= precio_bebida:
		_label_prompt.text = "[E] Buy Energy Soda ($%d)  |  +%d Energy" % [precio_bebida, int(energia_recuperada)]
	else:
		_label_prompt.text = "Energy Soda ($%d) - Not enough money!" % precio_bebida

func _unhandled_input(event: InputEvent) -> void:
	if not _jugador_cerca:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_F:
			_intentar_comprar()

func _intentar_comprar() -> void:
	if not _player_ref or not _player_ref.has_method("gastar_dinero"):
		return
	if _player_ref.gastar_dinero(precio_bebida):
		if _player_ref.has_method("recuperar_energia"):
			_player_ref.recuperar_energia(energia_recuperada)
		_audio_maquina.play()
		_tiempo_anim_lata = 0.85
		_lata_dispensada.visible = true
		_actualizar_prompt()

func _process(delta: float) -> void:
	if _jugador_cerca:
		_actualizar_prompt()
	
	if _tiempo_anim_lata > 0.0:
		_tiempo_anim_lata -= delta
		_lata_dispensada.position.z = 0.48 + sin((0.85 - _tiempo_anim_lata) * 6.0) * 0.14
		_lata_dispensada.rotation_degrees.z += delta * 360.0
		if _tiempo_anim_lata <= 0.0:
			_lata_dispensada.visible = false

# Sintetiza sonido de moneda cayendo + apertura de lata de refresco ("clink + psssh!")
func _preparar_audio_lata() -> void:
	var duracion: float = 0.35
	var muestras: int = int(SAMPLE_RATE * duracion)
	var datos := PackedByteArray()
	datos.resize(muestras * 2)
	
	for i: int in range(muestras):
		var t: float = float(i) / float(SAMPLE_RATE)
		var val: float = 0.0
		if t < 0.12:
			var env1: float = exp(-t * 35.0)
			val = (sin(TAU * 1850.0 * t) * 0.5 + sin(TAU * 2780.0 * t) * 0.4) * env1
		else:
			var t2: float = t - 0.12
			var env2: float = clamp(t2 / 0.02, 0.0, 1.0) * exp(-t2 * 14.0)
			val = _rng.randf_range(-1.0, 1.0) * env2 * 0.55
		datos.encode_s16(i * 2, int(clamp(val, -1.0, 1.0) * 32767.0))
	
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = datos
	
	_audio_maquina = AudioStreamPlayer.new()
	_audio_maquina.stream = wav
	_audio_maquina.volume_db = -6.0
	add_child(_audio_maquina)
