extends Node3D

@export_file("*.tscn") var ruta_intro: String = "res://Intro.tscn"
@export_file("*.tscn") var escena_monstruo_glb: String = "res://monstruo_peludo_godot.glb"
@export_file("*.mp3", "*.ogg", "*.wav") var musica_mp3: String = "res://boda.mp3"
@export var velocidad_scroll_creditos: float = 44.0

const SAMPLE_RATE: int = 22050
const BUS_GRAMOFONO: String = "GramofonoAntiguo"

enum FaseCinematica {
	CORRIENDO_1,      # Huyendo hacia adelante entre los árboles
	MIRANDO_ATRAS,    # Gira la cabeza 180° y ve al monstruo corriendo detrás
	CORRIENDO_2,      # Vuelve a mirar al frente y esprinta desesperado
	EMBOSCADA,        # El monstruo aparece por delante y lo atrapa
	CAYENDO_ARRIBA,   # La cámara cae de espaldas mirando a las copas de los árboles
	CREDITOS          # Suben los créditos del final alternativo
}

var _fase: FaseCinematica = FaseCinematica.CORRIENDO_1
var _tiempo_fase: float = 0.0
var _tiempo_total: float = 0.0

var _camara: Camera3D
var _pos_jugador := Vector3(0.0, 1.65, 0.0)
var _yaw_camara: float = 0.0
var _pitch_camara: float = 0.0
var _roll_camara: float = 0.0
var _fase_paso: float = 0.0

var _monstruo_nodo: Node3D
var _animador_monstruo: MonstruoAnimador
var _pos_monstruo := Vector3(0.0, 0.0, 7.5)

var _mm_troncos: MultiMeshInstance3D
var _mm_copas: MultiMeshInstance3D
var _arboles_data: Array[Dictionary] = []

var _label_creditos: Label
var _alto_pantalla: float = 720.0
var _flash_negro: ColorRect

var _audio_pasos: AudioStreamPlayer
var _audio_susto: AudioStreamPlayer
var _audio_musica: AudioStreamPlayer
var _audio_vinilo: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 91919
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_crear_entorno_y_luz()
	_crear_suelo_bosque()
	_crear_bosque_infinito()
	_crear_camara()
	_instanciar_monstruo()
	_preparar_audios()
	_crear_ui_creditos()

func _crear_entorno_y_luz() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.07, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.32, 0.35)
	env.ambient_light_energy = 0.85
	
	env.fog_enabled = true
	env.fog_light_color = Color(0.11, 0.11, 0.12)
	env.fog_density = 0.055
	we.environment = env
	add_child(we)
	
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-65.0, 25.0, 0.0)
	luz.light_energy = 1.15
	add_child(luz)

func _crear_suelo_bosque() -> void:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120.0, 220.0)
	mi.mesh = plane
	mi.position = Vector3(0.0, 0.0, -40.0)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.14, 0.15, 0.14)
	mat.roughness = 0.95
	mi.material_override = mat
	add_child(mi)

func _crear_bosque_infinito() -> void:
	# Generamos 180 árboles vóxel a ambos lados de un sendero estrecho que se reciclan en bucle
	var total_arboles: int = 180
	var mesh_cubo := BoxMesh.new()
	mesh_cubo.size = Vector3.ONE
	
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.92
	
	var mm_t := MultiMesh.new()
	mm_t.transform_format = MultiMesh.TRANSFORM_3D
	mm_t.use_colors = true
	mm_t.mesh = mesh_cubo
	mm_t.instance_count = total_arboles
	
	var mm_c := MultiMesh.new()
	mm_c.transform_format = MultiMesh.TRANSFORM_3D
	mm_c.use_colors = true
	mm_c.mesh = mesh_cubo
	mm_c.instance_count = total_arboles * 3
	
	for i: int in range(total_arboles):
		var lado: float = -1.0 if (i % 2 == 0) else 1.0
		var px: float = lado * _rng.randf_range(2.6, 22.0)
		var pz: float = _rng.randf_range(-95.0, 25.0)
		var eh: float = _rng.randf_range(1.0, 1.65)
		var ew: float = _rng.randf_range(0.95, 1.45)
		var rot := Basis(Vector3.UP, float(_rng.randi() % 4) * (PI * 0.5))
		
		var tono_t: float = _rng.randf_range(0.14, 0.22)
		mm_t.set_instance_color(i, Color(tono_t, tono_t, tono_t))
		
		var tono_c: float = _rng.randf_range(0.18, 0.32)
		var col_c := Color(tono_c * 0.8, tono_c, tono_c * 0.8)
		for k: int in range(3):
			mm_c.set_instance_color(i * 3 + k, col_c)
		
		_arboles_data.append({
			"x": px,
			"z": pz,
			"eh": eh,
			"ew": ew,
			"rot": rot
		})
	
	_mm_troncos = MultiMeshInstance3D.new()
	_mm_troncos.multimesh = mm_t
	_mm_troncos.material_override = mat
	_mm_troncos.extra_cull_margin = 120.0
	add_child(_mm_troncos)
	
	_mm_copas = MultiMeshInstance3D.new()
	_mm_copas.multimesh = mm_c
	_mm_copas.material_override = mat
	_mm_copas.extra_cull_margin = 120.0
	add_child(_mm_copas)
	
	_actualizar_instancias_bosque(0.0)

func _actualizar_instancias_bosque(avance_z: float) -> void:
	var mm_t: MultiMesh = _mm_troncos.multimesh
	var mm_c: MultiMesh = _mm_copas.multimesh
	
	for i: int in range(_arboles_data.size()):
		var d: Dictionary = _arboles_data[i]
		d["z"] += avance_z
		if d["z"] > 22.0:
			d["z"] -= 120.0
		
		var px: float = d["x"]
		var pz: float = d["z"]
		var eh: float = d["eh"]
		var ew: float = d["ew"]
		var rot: Basis = d["rot"]
		
		var alto_t: float = 2.8 * eh
		var b_t := rot.scaled(Vector3(0.55 * ew, alto_t, 0.55 * ew))
		mm_t.set_instance_transform(i, Transform3D(b_t, Vector3(px, alto_t * 0.5, pz)))
		
		var niveles: Array[Array] = [
			[alto_t + 0.5 * eh, 2.7 * ew, 1.4 * eh],
			[alto_t + 1.7 * eh, 1.8 * ew, 1.3 * eh],
			[alto_t + 2.8 * eh, 1.0 * ew, 1.1 * eh]
		]
		for k: int in range(3):
			var niv: Array = niveles[k]
			var b_c := rot.scaled(Vector3(niv[1], niv[2], niv[1]))
			mm_c.set_instance_transform(i * 3 + k, Transform3D(b_c, Vector3(px, niv[0], pz)))

func _crear_camara() -> void:
	_camara = Camera3D.new()
	_camara.fov = 78.0
	_camara.position = _pos_jugador
	add_child(_camara)
	_camara.make_current()

func _instanciar_monstruo() -> void:
	if not ResourceLoader.exists(escena_monstruo_glb):
		push_warning("final_bosque.gd: No se encontró " + escena_monstruo_glb)
		return
	var packed: PackedScene = load(escena_monstruo_glb)
	_monstruo_nodo = packed.instantiate()
	_monstruo_nodo.position = _pos_monstruo
	_monstruo_nodo.rotation.y = PI # Mirando hacia -Z (persiguiendo al jugador)
	add_child(_monstruo_nodo)
	
	var skel := _buscar_skeleton(_monstruo_nodo)
	if skel:
		_animador_monstruo = MonstruoAnimador.new(skel, 1.28)

func _buscar_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c: Node in n.get_children():
		var res := _buscar_skeleton(c)
		if res:
			return res
	return null

func _process(delta: float) -> void:
	_tiempo_total += delta
	_tiempo_fase += delta
	
	match _fase:
		FaseCinematica.CORRIENDO_1:
			_procesar_carrera(delta, 8.8)
			_yaw_camara = lerp(_yaw_camara, sin(_tiempo_total * 2.2) * 0.06, delta * 6.0)
			_pitch_camara = lerp(_pitch_camara, -0.04, delta * 6.0)
			if _animador_monstruo:
				_animador_monstruo.actualizar(delta, 7.5, true, false)
			if _tiempo_fase >= 3.2:
				_cambiar_fase(FaseCinematica.MIRANDO_ATRAS)
		
		FaseCinematica.MIRANDO_ATRAS:
			# Sigue corriendo mientras gira la cabeza 180° hacia atrás para ver al Stalker
			_procesar_carrera(delta, 7.6)
			_yaw_camara = lerp_angle(_yaw_camara, PI - 0.12, delta * 7.5)
			_pitch_camara = lerp(_pitch_camara, -0.08, delta * 6.0)
			if _monstruo_nodo:
				# El monstruo se acerca cada vez más por detrás (+Z)
				_pos_monstruo.z = lerp(_pos_monstruo.z, 3.1, delta * 1.4)
				_pos_monstruo.x = sin(_tiempo_total * 6.0) * 0.35
				_monstruo_nodo.position = _pos_monstruo
				_monstruo_nodo.rotation.y = PI
			if _animador_monstruo:
				_animador_monstruo.actualizar(delta, 8.5, true, false)
			if _tiempo_fase >= 2.7:
				_cambiar_fase(FaseCinematica.CORRIENDO_2)
		
		FaseCinematica.CORRIENDO_2:
			# Vuelve a girar hacia delante corriendo aún más rápido
			_procesar_carrera(delta, 9.8)
			_yaw_camara = lerp_angle(_yaw_camara, 0.0, delta * 9.0)
			_pitch_camara = lerp(_pitch_camara, -0.02, delta * 6.0)
			if _animador_monstruo:
				_animador_monstruo.actualizar(delta, 8.5, true, false)
			if _tiempo_fase >= 2.3:
				_cambiar_fase(FaseCinematica.EMBOSCADA)
		
		FaseCinematica.EMBOSCADA:
			# El monstruo te corta el paso por delante (-Z) y te atrapa
			_actualizar_instancias_bosque(delta * 2.0)
			_yaw_camara = lerp_angle(_yaw_camara, sin(_tiempo_total * 28.0) * 0.08, delta * 12.0)
			_pitch_camara = lerp(_pitch_camara, 0.05, delta * 10.0)
			_roll_camara = sin(_tiempo_total * 34.0) * 0.09
			
			if _monstruo_nodo:
				_pos_monstruo = _pos_monstruo.lerp(Vector3(0.0, 0.0, -1.15), delta * 11.0)
				_monstruo_nodo.position = _pos_monstruo
				_monstruo_nodo.rotation.y = 0.0 # De cara al jugador
			if _animador_monstruo:
				_animador_monstruo.actualizar(delta, 0.0, true, true)
			
			if _tiempo_fase >= 1.35:
				_cambiar_fase(FaseCinematica.CAYENDO_ARRIBA)
		
		FaseCinematica.CAYENDO_ARRIBA:
			# Caes al suelo de espaldas y la cámara queda mirando hacia arriba (copas de los árboles)
			_pos_jugador.y = lerp(_pos_jugador.y, 0.28, delta * 4.5)
			_pitch_camara = lerp(_pitch_camara, deg_to_rad(82.0), delta * 3.8)
			_roll_camara = lerp(_roll_camara, deg_to_rad(14.0), delta * 3.2)
			_yaw_camara = lerp_angle(_yaw_camara, 0.15, delta * 2.5)
			
			if _monstruo_nodo:
				# El monstruo se retira hacia la oscuridad del bosque tras atraparte
				_monstruo_nodo.position.z -= delta * 3.5
			if _animador_monstruo:
				_animador_monstruo.actualizar(delta, 4.0, false, false)
			
			if _tiempo_fase >= 2.2:
				_cambiar_fase(FaseCinematica.CREDITOS)
		
		FaseCinematica.CREDITOS:
			# Cámara en el suelo mirando hacia arriba a las copas mientras suben los créditos
			_pitch_camara = deg_to_rad(82.0) + sin(_tiempo_total * 0.6) * 0.02
			_roll_camara = deg_to_rad(14.0) + cos(_tiempo_total * 0.5) * 0.015
			_actualizar_scroll_creditos(delta)
	
	# Aplicar transformaciones a la cámara
	if _camara:
		_camara.position = _pos_jugador
		_camara.rotation = Vector3(_pitch_camara, _yaw_camara, _roll_camara)
	
	# Oscilación de disco viejo en la música de créditos
	if _audio_musica and _audio_musica.playing:
		var wow: float = sin(_tiempo_total * 3.1) * 0.012 + cos(_tiempo_total * 11.4) * 0.005
		_audio_musica.pitch_scale = 0.96 + wow

func _cambiar_fase(nueva: FaseCinematica) -> void:
	_fase = nueva
	_tiempo_fase = 0.0
	
	if nueva == FaseCinematica.EMBOSCADA:
		if _monstruo_nodo:
			_pos_monstruo = Vector3(0.0, 0.0, -4.5)
			_monstruo_nodo.position = _pos_monstruo
			_monstruo_nodo.rotation.y = 0.0
		if _audio_susto:
			_audio_susto.play()
	
	elif nueva == FaseCinematica.CAYENDO_ARRIBA:
		_flash_negro.modulate.a = 0.85
		var tw := create_tween()
		tw.tween_property(_flash_negro, "modulate:a", 0.0, 0.9)
		_iniciar_audio_creditos()
	
	elif nueva == FaseCinematica.CREDITOS:
		_label_creditos.visible = true
		_alto_pantalla = get_viewport().get_visible_rect().size.y
		_label_creditos.position.y = _alto_pantalla + 40.0

func _procesar_carrera(delta: float, velocidad: float) -> void:
	_actualizar_instancias_bosque(velocidad * delta)
	
	var fase_ant: float = _fase_paso
	_fase_paso += delta * (velocidad * 0.36) * TAU
	
	if int(floor(_fase_paso / PI)) > int(floor(fase_ant / PI)):
		if _audio_pasos:
			_audio_pasos.pitch_scale = _rng.randf_range(0.92, 1.08)
			_audio_pasos.play()
	
	_pos_jugador.y = 1.65 - abs(sin(_fase_paso)) * 0.065
	_pos_jugador.x = cos(_fase_paso) * 0.045
	_roll_camara = sin(_fase_paso) * 0.022

func _actualizar_scroll_creditos(delta: float) -> void:
	if not _label_creditos or not _label_creditos.visible:
		return
	_label_creditos.position.y -= velocidad_scroll_creditos * delta
	var alto_texto: float = _label_creditos.size.y if _label_creditos.size.y > 0.0 else 860.0
	if _label_creditos.position.y < -alto_texto - 40.0:
		_alto_pantalla = get_viewport().get_visible_rect().size.y
		_label_creditos.position.y = _alto_pantalla + 40.0

func _crear_ui_creditos() -> void:
	var capa := CanvasLayer.new()
	capa.name = "CapaCreditosBosque"
	capa.layer = 10
	add_child(capa)
	
	_flash_negro = ColorRect.new()
	_flash_negro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_negro.color = Color(0.0, 0.0, 0.0, 1.0)
	_flash_negro.modulate.a = 0.0
	_flash_negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(_flash_negro)
	
	var texto: String = """JANITOR ACTIVITIES
- ENDING II: INTO THE WOODS -


DIRECTED BY
KULER DUDER


YOU TRIED TO ABANDON YOUR SHIFT.
THE FOREST NEVER LETS YOU LEAVE.


CLEANING REPORT
STATUS: ABANDONED
JANITOR: MISSING IN THE TREES


STARRING
THE JANITOR
& THE STALKER OF THE WOODS


"THE SCHOOL WAS THE ONLY SAFE PLACE."


THANK YOU FOR PLAYING
JANITOR ACTIVITIES


[ PRESS R TO RETURN TO TITLE ]
"""
	
	_label_creditos = Label.new()
	_label_creditos.text = texto
	_label_creditos.visible = false
	_label_creditos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_creditos.add_theme_font_size_override("font_size", 28)
	_label_creditos.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	_label_creditos.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	_label_creditos.add_theme_constant_override("shadow_offset_x", 3)
	_label_creditos.add_theme_constant_override("shadow_offset_y", 3)
	_label_creditos.set_anchors_preset(Control.PRESET_TOP_WIDE)
	capa.add_child(_label_creditos)

func _preparar_audios() -> void:
	_audio_pasos = AudioStreamPlayer.new()
	_audio_pasos.stream = _sintetizar_paso_tierra()
	_audio_pasos.volume_db = -6.0
	add_child(_audio_pasos)
	
	_audio_susto = AudioStreamPlayer.new()
	_audio_susto.stream = _sintetizar_rugido(1.3, 180.0, 540.0)
	_audio_susto.volume_db = -1.5
	add_child(_audio_susto)

func _iniciar_audio_creditos() -> void:
	var bus_idx: int = AudioServer.get_bus_index(BUS_GRAMOFONO)
	if bus_idx == -1:
		AudioServer.add_bus()
		bus_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(bus_idx, BUS_GRAMOFONO)
		AudioServer.set_bus_send(bus_idx, "Master")
		
		var hp := AudioEffectHighPassFilter.new()
		hp.cutoff_hz = 320.0
		AudioServer.add_bus_effect(bus_idx, hp)
		
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 2600.0
		AudioServer.add_bus_effect(bus_idx, lp)
	
	if ResourceLoader.exists(musica_mp3):
		var st: AudioStream = load(musica_mp3)
		if st is AudioStreamMP3:
			st.loop = true
		_audio_musica = AudioStreamPlayer.new()
		_audio_musica.stream = st
		_audio_musica.bus = BUS_GRAMOFONO
		_audio_musica.volume_db = -5.0
		add_child(_audio_musica)
		_audio_musica.play()
	
	_audio_vinilo = AudioStreamPlayer.new()
	_audio_vinilo.stream = _sintetizar_ruido_vinilo()
	_audio_vinilo.bus = BUS_GRAMOFONO
	_audio_vinilo.volume_db = -18.0
	add_child(_audio_vinilo)
	_audio_vinilo.play()

func _sintetizar_paso_tierra() -> AudioStreamWAV:
	var dur: float = 0.11
	var n: int = int(SAMPLE_RATE * dur)
	var datos := PackedByteArray()
	datos.resize(n * 2)
	var lp: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-t * 42.0)
		var golpe: float = sin(TAU * 75.0 * t) * 0.65
		lp = lerp(lp, _rng.randf_range(-1.0, 1.0), 0.25)
		var s: float = clamp((golpe + lp * 0.75) * env * 0.75, -1.0, 1.0)
		datos.encode_s16(i * 2, int(s * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.data = datos
	return wav

func _sintetizar_rugido(dur: float, f0: float, f1: float) -> AudioStreamWAV:
	var n: int = int(SAMPLE_RATE * dur)
	var datos := PackedByteArray()
	datos.resize(n * 2)
	var fase: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / dur
		var freq: float = lerp(f0, f1, p) + sin(t * 50.0) * 20.0
		fase += (TAU * freq) / float(SAMPLE_RATE)
		var env: float = clamp(t / 0.03, 0.0, 1.0) * clamp((dur - t) / 0.12, 0.0, 1.0)
		var raw: float = sin(fase) * 0.6 + _rng.randf_range(-1.0, 1.0) * 0.5
		var s: float = tanh(raw * 2.4) * env * 0.8
		datos.encode_s16(i * 2, int(clamp(s, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.data = datos
	return wav

func _sintetizar_ruido_vinilo() -> AudioStreamWAV:
	var n: int = SAMPLE_RATE * 2
	var datos := PackedByteArray()
	datos.resize(n * 2)
	for i: int in range(n):
		var base: float = _rng.randf_range(-1.0, 1.0) * 0.08
		var click: float = _rng.randf_range(-0.75, 0.75) if _rng.randf() > 0.9975 else 0.0
		datos.encode_s16(i * 2, int(clamp(base + click, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = n
	wav.data = datos
	return wav

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		if ResourceLoader.exists(ruta_intro):
			get_tree().change_scene_to_file(ruta_intro)
