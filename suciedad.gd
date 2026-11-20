extends Node3D

@export var cantidad_voxels: int = 4500
@export var tamano_voxel: float = 0.15
@export var valor_por_voxel: int = 1
@export var volumen_gotita_db: float = -10.0

# Ajustes para el final (bájalo a 0.5 o 1.0 en el inspector para probar rápido, déjalo en 100.0 para el juego final)
@export_range(0.1, 100.0, 0.1) var porcentaje_para_final: float = 100.0
@export_file("*.tscn") var ruta_escena_final: String = "res://Final.tscn"

const CELL_SIZE: float = 1.5
const MICRO_GRID: float = 0.18
const Y_SUELO: float = 0.05
const SAMPLE_RATE: int = 22050

var _mm_instance: MultiMeshInstance3D
var _multimesh: MultiMesh

var _posiciones: PackedVector3Array = PackedVector3Array()
var _velocidades: PackedVector3Array = PackedVector3Array()
var _estados: PackedByteArray = PackedByteArray() # 0 = reposo, 1 = succión, 2 = recogido, 3 = física falsa
var _progreso_succion: PackedFloat32Array = PackedFloat32Array()
var _rotaciones: Array[Basis] = []

var _grid: Dictionary = {}
var _en_succion: Array[int] = []
var _en_fisica: Array[int] = []

var _total_activos: int = 0
var _recogidos: int = 0
var _final_activado: bool = false
var _label_progreso: Label
var _rng := RandomNumberGenerator.new()

var _wav_gotita: AudioStreamWAV
var _pool_audio: Array[AudioStreamPlayer] = []
var _indice_audio: int = 0
var _racha_pitch: float = 0.0
var _tiempo_sin_recoger: float = 0.0

func _ready() -> void:
	add_to_group("gestor_suciedad")
	_rng.seed = 98765
	_preparar_audio_gotita()
	_crear_hud_limpieza()
	call_deferred("_generar_suciedad_limpia")

func _unhandled_input(event: InputEvent) -> void:
	# Tecla F9 de depuración para probar la transición al final al instante
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		_disparar_final()

func _preparar_audio_gotita() -> void:
	_wav_gotita = _sintetizar_gotita()
	for i: int in range(8):
		var asp := AudioStreamPlayer.new()
		asp.name = "SonidoGotita_" + str(i)
		asp.stream = _wav_gotita
		asp.volume_db = volumen_gotita_db
		add_child(asp)
		_pool_audio.append(asp)

func _sintetizar_gotita() -> AudioStreamWAV:
	var duracion: float = 0.075
	var num_muestras: int = int(SAMPLE_RATE * duracion)
	var datos := PackedByteArray()
	datos.resize(num_muestras * 2)
	
	var fase: float = 0.0
	for i: int in range(num_muestras):
		var t: float = float(i) / float(SAMPLE_RATE)
		var progreso: float = t / duracion
		var freq: float = lerp(460.0, 1020.0, progreso * progreso)
		fase += (TAU * freq) / float(SAMPLE_RATE)
		
		var ataque: float = clamp(t / 0.005, 0.0, 1.0)
		var caida: float = exp(-progreso * 4.2)
		var env: float = ataque * caida
		
		var onda: float = sin(fase) * 0.85 + sin(fase * 2.0) * 0.15
		var muestra: float = clamp(onda * env * 0.65, -1.0, 1.0)
		datos.encode_s16(i * 2, int(muestra * 32767.0))
	
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = datos
	return wav

func _reproducir_sonido_gotita() -> void:
	if _pool_audio.is_empty():
		return
	var asp: AudioStreamPlayer = _pool_audio[_indice_audio]
	_indice_audio = (_indice_audio + 1) % _pool_audio.size()
	
	_racha_pitch = min(_racha_pitch + 0.025, 0.35)
	_tiempo_sin_recoger = 0.0
	
	asp.pitch_scale = 0.96 + _racha_pitch + _rng.randf_range(-0.03, 0.03)
	asp.volume_db = volumen_gotita_db
	asp.play()

func _crear_hud_limpieza() -> void:
	var capa := CanvasLayer.new()
	capa.name = "HUD_Limpieza"
	add_child(capa)
	
	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	margen.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	margen.add_theme_constant_override("margin_right", 24)
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
	
	_label_progreso = Label.new()
	_label_progreso.add_theme_font_size_override("font_size", 18)
	_label_progreso.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	panel.add_child(_label_progreso)

func _generar_suciedad_limpia() -> void:
	var num_manchas: int = max(40, int(cantidad_voxels / 55))
	var centros_mugre: Array[Vector2] = []
	for i: int in range(num_manchas):
		var cx: float = _rng.randf_range(-24.5, 24.5)
		var cz: float = _rng.randf_range(-44.5, -13.5)
		if not _es_posicion_prohibida(cx, cz):
			centros_mugre.append(Vector2(cx, cz))
	
	var celdas_ocupadas: Dictionary = {}
	var puntos: Array[Vector3] = []
	var intentos: int = 0
	var max_intentos: int = cantidad_voxels * 8
	
	while puntos.size() < cantidad_voxels and intentos < max_intentos:
		intentos += 1
		var px: float
		var pz: float
		
		if _rng.randf() < 0.78 and not centros_mugre.is_empty():
			var c: Vector2 = centros_mugre[_rng.randi() % centros_mugre.size()]
			var ang: float = _rng.randf() * TAU
			var rad: float = abs(_rng.randfn(0.0, 1.15))
			px = c.x + cos(ang) * rad
			pz = c.y + sin(ang) * rad
		else:
			px = _rng.randf_range(-25.0, 25.0)
			pz = _rng.randf_range(-45.0, -13.0)
		
		var gx: int = int(floor(px / MICRO_GRID))
		var gz: int = int(floor(pz / MICRO_GRID))
		var micro_key := Vector2i(gx, gz)
		if celdas_ocupadas.has(micro_key):
			continue
		
		var final_x: float = (float(gx) + 0.5 + _rng.randf_range(-0.18, 0.18)) * MICRO_GRID
		var final_z: float = (float(gz) + 0.5 + _rng.randf_range(-0.18, 0.18)) * MICRO_GRID
		
		if _es_posicion_prohibida(final_x, final_z):
			continue
		
		celdas_ocupadas[micro_key] = true
		puntos.append(Vector3(final_x, Y_SUELO, final_z))
	
	_total_activos = puntos.size()
	_posiciones.resize(_total_activos)
	_velocidades.resize(_total_activos)
	_estados.resize(_total_activos)
	_progreso_succion.resize(_total_activos)
	_rotaciones.resize(_total_activos)
	
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	
	var box := BoxMesh.new()
	box.size = Vector3(tamano_voxel, tamano_voxel * 0.65, tamano_voxel)
	_multimesh.mesh = box
	_multimesh.instance_count = _total_activos
	
	var tonos: Array[Color] = [
		Color(0.16, 0.15, 0.14),
		Color(0.30, 0.27, 0.23),
		Color(0.86, 0.85, 0.80),
		Color(0.11, 0.11, 0.11)
	]
	
	for i: int in range(_total_activos):
		var pos: Vector3 = puntos[i]
		_posiciones[i] = pos
		_velocidades[i] = Vector3.ZERO
		_estados[i] = 0
		_progreso_succion[i] = 0.0
		
		var rot := Basis(Vector3.UP, _rng.randf() * TAU)
		_rotaciones[i] = rot
		_multimesh.set_instance_transform(i, Transform3D(rot, pos))
		_multimesh.set_instance_color(i, tonos[_rng.randi() % tonos.size()])
		
		var celda := _world_to_cell(pos.x, pos.z)
		if not _grid.has(celda):
			_grid[celda] = []
		_grid[celda].append(i)
	
	_mm_instance = MultiMeshInstance3D.new()
	_mm_instance.name = "MultiMeshSuciedad"
	_mm_instance.multimesh = _multimesh
	_mm_instance.extra_cull_margin = 50.0
	
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	_mm_instance.material_override = mat
	add_child(_mm_instance)
	
	_actualizar_hud()

func _es_posicion_prohibida(x: float, z: float) -> bool:
	var mapas := get_tree().get_nodes_in_group("mapa_instituto")
	if not mapas.is_empty():
		var mapa: Node = mapas[0]
		if mapa.esta_bloqueado(x, z) or mapa.es_zona_segura(Vector3(x, 1.0, z)):
			return true
		return false
	return (x < -25.1 or x > 25.1 or z < -45.1 or z > -12.9)

func _world_to_cell(x: float, z: float) -> Vector2i:
	return Vector2i(int(floor(x / CELL_SIZE)), int(floor(z / CELL_SIZE)))

func _mover_de_celda(idx: int, old_pos: Vector3, new_pos: Vector3) -> void:
	var c_old := _world_to_cell(old_pos.x, old_pos.z)
	var c_new := _world_to_cell(new_pos.x, new_pos.z)
	if c_old != c_new:
		if _grid.has(c_old):
			_grid[c_old].erase(idx)
		if not _grid.has(c_new):
			_grid[c_new] = []
		_grid[c_new].append(idx)

func intentar_aspirar(punto_suelo: Vector3, _boquilla_pos: Vector3, radio: float, max_a_capturar: int) -> int:
	if not _multimesh:
		return 0
	
	var capturados: int = 0
	var radio_sq: float = radio * radio
	var c_min := _world_to_cell(punto_suelo.x - radio, punto_suelo.z - radio)
	var c_max := _world_to_cell(punto_suelo.x + radio, punto_suelo.z + radio)
	
	for cx: int in range(c_min.x, c_max.x + 1):
		for cz: int in range(c_min.y, c_max.y + 1):
			var celda := Vector2i(cx, cz)
			if not _grid.has(celda):
				continue
			var lista: Array = _grid[celda]
			for idx: int in lista:
				var st: int = _estados[idx]
				if st == 1 or st == 2:
					continue
				var p: Vector3 = _posiciones[idx]
				var dx: float = p.x - punto_suelo.x
				var dz: float = p.z - punto_suelo.z
				var dist_sq: float = dx * dx + dz * dz
				
				if dist_sq <= radio_sq:
					if capturados < max_a_capturar:
						_estados[idx] = 1
						_progreso_succion[idx] = 0.0
						_en_succion.append(idx)
						capturados += 1
					elif st == 0:
						var dir_succion := Vector3(-dx, 0.0, -dz).normalized()
						_velocidades[idx] = dir_succion * _rng.randf_range(0.6, 1.4) + Vector3(0.0, _rng.randf_range(0.8, 1.5), 0.0)
						_estados[idx] = 3
						_en_fisica.append(idx)
	return capturados

func _process(delta: float) -> void:
	_tiempo_sin_recoger += delta
	if _tiempo_sin_recoger > 0.45:
		_racha_pitch = max(0.0, _racha_pitch - delta * 0.5)
	
	var jugadores := get_tree().get_nodes_in_group("jugador")
	if not jugadores.is_empty():
		var jugador: CharacterBody3D = jugadores[0]
		_aplicar_pisadas_falsa_fisica(jugador)
		_procesar_succion_activa(delta, jugador)
	
	_procesar_fisica_falsa(delta)

func _aplicar_pisadas_falsa_fisica(jugador: CharacterBody3D) -> void:
	var vel_horiz := Vector2(jugador.velocity.x, jugador.velocity.z).length()
	if vel_horiz < 0.8 or not jugador.is_on_floor():
		return
	
	var pos_j: Vector3 = jugador.global_position
	var radio_pie: float = 0.55
	var radio_sq: float = radio_pie * radio_pie
	var c_min := _world_to_cell(pos_j.x - radio_pie, pos_j.z - radio_pie)
	var c_max := _world_to_cell(pos_j.x + radio_pie, pos_j.z + radio_pie)
	
	for cx: int in range(c_min.x, c_max.x + 1):
		for cz: int in range(c_min.y, c_max.y + 1):
			var celda := Vector2i(cx, cz)
			if not _grid.has(celda):
				continue
			for idx: int in _grid[celda]:
				if _estados[idx] != 0:
					continue
				var p: Vector3 = _posiciones[idx]
				var dx: float = p.x - pos_j.x
				var dz: float = p.z - pos_j.z
				var d_sq: float = dx * dx + dz * dz
				if d_sq <= radio_sq and d_sq > 0.0001:
					var empujon := Vector3(dx, 0.0, dz).normalized() * (vel_horiz * 0.35)
					empujon.y = _rng.randf_range(1.1, 2.2)
					_velocidades[idx] = empujon
					_estados[idx] = 3
					_en_fisica.append(idx)

func _procesar_fisica_falsa(delta: float) -> void:
	if _en_fisica.is_empty():
		return
	
	var i: int = _en_fisica.size() - 1
	while i >= 0:
		var idx: int = _en_fisica[i]
		if _estados[idx] != 3:
			_en_fisica.remove_at(i)
			i -= 1
			continue
		
		var pos_anterior: Vector3 = _posiciones[idx]
		var pos: Vector3 = pos_anterior
		var vel: Vector3 = _velocidades[idx]
		
		vel.y -= 9.8 * delta
		var sig_x: float = pos.x + vel.x * delta
		var sig_z: float = pos.z + vel.z * delta
		
		if _es_posicion_prohibida(sig_x, pos.z):
			vel.x = -vel.x * 0.4
		else:
			pos.x = sig_x
			
		if _es_posicion_prohibida(pos.x, sig_z):
			vel.z = -vel.z * 0.4
		else:
			pos.z = sig_z
		
		pos.y += vel.y * delta
		
		if pos.y <= Y_SUELO:
			pos.y = Y_SUELO
			if abs(vel.y) > 0.45:
				vel.y = -vel.y * 0.35
				vel.x *= 0.65
				vel.z *= 0.65
			else:
				vel = Vector3.ZERO
		
		_posiciones[idx] = pos
		_velocidades[idx] = vel
		_mover_de_celda(idx, pos_anterior, pos)
		
		if pos.y > Y_SUELO + 0.01:
			_rotaciones[idx] = _rotaciones[idx].rotated(Vector3.UP, delta * 6.0)
		
		_multimesh.set_instance_transform(idx, Transform3D(_rotaciones[idx], pos))
		
		if vel == Vector3.ZERO and pos.y <= Y_SUELO:
			_estados[idx] = 0
			_en_fisica.remove_at(i)
		
		i -= 1

func _procesar_succion_activa(delta: float, jugador: CharacterBody3D) -> void:
	if _en_succion.is_empty():
		return
	
	var boquilla: Vector3 = jugador.global_position + Vector3(0.0, 0.95, 0.0) - jugador.global_transform.basis.z * 0.6
	var player_nodo: Node = jugador.get_parent()
	
	var i: int = _en_succion.size() - 1
	while i >= 0:
		var idx: int = _en_succion[i]
		_progreso_succion[idx] += delta * 5.5
		var t: float = _progreso_succion[idx]
		
		if t >= 1.0:
			_estados[idx] = 2
			_multimesh.set_instance_transform(idx, Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -50, 0)))
			_en_succion.remove_at(i)
			_recogidos += 1
			_reproducir_sonido_gotita()
			if player_nodo and player_nodo.has_method("ganar_dinero"):
				player_nodo.ganar_dinero(valor_por_voxel)
			_actualizar_hud()
		else:
			var origen: Vector3 = _posiciones[idx]
			var pos_actual: Vector3 = origen.lerp(boquilla, t * t)
			var escala: float = lerp(1.0, 0.15, t)
			var b: Basis = _rotaciones[idx].rotated(Vector3.UP, t * 10.0).scaled(Vector3.ONE * escala)
			_multimesh.set_instance_transform(idx, Transform3D(b, pos_actual))
		i -= 1

func _actualizar_hud() -> void:
	if not _label_progreso:
		return
	var pct: float = 0.0
	if _total_activos > 0:
		pct = (float(_recogidos) / float(_total_activos)) * 100.0
	
	if porcentaje_para_final < 100.0:
		_label_progreso.text = "CLEANED: %d / %d (%.1f%% / %.1f%%)" % [_recogidos, _total_activos, pct, porcentaje_para_final]
	else:
		_label_progreso.text = "CLEANED: %d / %d (%.1f%%)" % [_recogidos, _total_activos, pct]
	
	# Comprobación dinámica para saltar al final
	if not _final_activado and _total_activos > 0 and pct >= porcentaje_para_final:
		_disparar_final()

func _disparar_final() -> void:
	if _final_activado:
		return
	_final_activado = true
	if _label_progreso:
		_label_progreso.text = "SHIFT COMPLETE!"
	
	await get_tree().create_timer(1.1).timeout
	if ResourceLoader.exists(ruta_escena_final):
		get_tree().change_scene_to_file(ruta_escena_final)
	else:
		push_warning("Aún no has creado la escena: " + ruta_escena_final)
