extends Node3D

@export var vidas_maximas: int = 3
@export_file("*.tscn") var ruta_intro: String = "res://Intro.tscn"

@export var tiempo_entre_apariciones: float = 35.0
@export var duracion_ronda_acecho: float = 45.0
@export var velocidad_patrulla: float = 2.6
@export var velocidad_persecucion: float = 5.2
@export var rango_vision: float = 15.0
@export var rango_oido_aspiradora: float = 16.0
@export var volumen_latido_db: float = -8.0

const SAMPLE_RATE: int = 22050
const Y_SUELO: float = 0.0

enum Estado { HIDDEN, PATROL, INVESTIGATE, CHASE, STALK_DOOR, JUMPSCARE }
var estado_actual: Estado = Estado.HIDDEN

var vidas_actuales: int = 3

var _modelo_raiz: Node3D
var _skel: Skeleton3D
var _animador: MonstruoAnimador

var _timer_estado: float = 0.0
var _timer_ronda: float = 0.0
var _timer_aviso: float = 0.0
var _ruta_puntos: Array[Vector3] = []
var _pos_acecho_puerta := Vector3(-2.6, Y_SUELO, -16.5)

# HUD de radar/reloj, latidos y 3 corazones de vida
var _label_alerta: Label
var _panel_radar: PanelContainer
var _label_icono_estado: Label
var _label_reloj: Label
var _label_corazon: Label
var _labels_vidas: Array[Label] = []
var _capa_gameover: ColorRect
var _timer_latido: float = 0.0
var _escala_corazon: float = 1.0

var _audio_latido: AudioStreamPlayer
var _audio_alerta: AudioStreamPlayer
var _audio_susto: AudioStreamPlayer
var _audio_pasos_monstruo: AudioStreamPlayer3D
var _timer_paso_audio: float = 0.0
var _rng := RandomNumberGenerator.new()
var _waypoints: Dictionary = {}

func _ready() -> void:
	add_to_group("gestor_monstruo")
	vidas_actuales = vidas_maximas
	_rng.seed = 66613
	_construir_grafo_navegacion()
	_crear_hud_alerta()
	_actualizar_hud_vidas()
	_preparar_audios_monstruo()
	call_deferred("_vincular_modelo_glb")

func _vincular_modelo_glb() -> void:
	for hijo: Node in get_children():
		if hijo is Node3D:
			_modelo_raiz = hijo
			_skel = _buscar_skeleton_recursivo(hijo)
			if _skel:
				break
	
	if not _skel:
		push_warning("Monstruo: No se encontró un Skeleton3D dentro de los hijos del nodo Monstruo.")
		return
	
	_animador = MonstruoAnimador.new(_skel, 1.28)
	_ocultar_monstruo()
	_timer_estado = tiempo_entre_apariciones

func _buscar_skeleton_recursivo(nodo: Node) -> Skeleton3D:
	if nodo is Skeleton3D:
		return nodo
	for c: Node in nodo.get_children():
		var res := _buscar_skeleton_recursivo(c)
		if res:
			return res
	return null

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		if estado_actual == Estado.JUMPSCARE:
			return
		_iniciar_aparicion()

func _construir_grafo_navegacion() -> void:
	_waypoints = {
		"entrada":      {"pos": Vector3(0.0, Y_SUELO, -13.5),   "vecinos": ["lobby_sur"]},
		"lobby_sur":    {"pos": Vector3(0.0, Y_SUELO, -16.5),   "vecinos": ["entrada", "lobby_centro"]},
		"lobby_centro": {"pos": Vector3(0.0, Y_SUELO, -23.0),   "vecinos": ["lobby_sur", "cruce", "secretaria"]},
		"cruce":        {"pos": Vector3(0.0, Y_SUELO, -29.0),   "vecinos": ["lobby_centro", "pasillo_o1", "pasillo_e1", "salon"]},
		"pasillo_o1":   {"pos": Vector3(-7.5, Y_SUELO, -29.0),  "vecinos": ["cruce", "pasillo_o2", "aula_n3"]},
		"pasillo_o2":   {"pos": Vector3(-14.5, Y_SUELO, -29.0), "vecinos": ["pasillo_o1", "pasillo_o3", "aula_s1", "aula_n2"]},
		"pasillo_o3":   {"pos": Vector3(-22.0, Y_SUELO, -29.0), "vecinos": ["pasillo_o2", "aula_s2", "aula_n1"]},
		"pasillo_e1":   {"pos": Vector3(7.5, Y_SUELO, -29.0),   "vecinos": ["cruce", "pasillo_e2", "aula_s3", "aula_n4"]},
		"pasillo_e2":   {"pos": Vector3(14.5, Y_SUELO, -29.0),  "vecinos": ["pasillo_e1", "pasillo_e3", "aula_s4", "banos"]},
		"pasillo_e3":   {"pos": Vector3(22.0, Y_SUELO, -29.0),  "vecinos": ["pasillo_e2", "almacen", "gimnasio"]},
		"secretaria":   {"pos": Vector3(7.5, Y_SUELO, -19.0),   "vecinos": ["lobby_centro"]},
		"aula_s1":      {"pos": Vector3(-14.5, Y_SUELO, -19.0), "vecinos": ["pasillo_o2"]},
		"aula_s2":      {"pos": Vector3(-22.0, Y_SUELO, -19.0), "vecinos": ["pasillo_o3"]},
		"aula_s3":      {"pos": Vector3(7.5, Y_SUELO, -19.0),   "vecinos": ["pasillo_e1"]},
		"aula_s4":      {"pos": Vector3(14.5, Y_SUELO, -19.0),  "vecinos": ["pasillo_e2"]},
		"almacen":      {"pos": Vector3(22.0, Y_SUELO, -19.0),  "vecinos": ["pasillo_e3"]},
		"aula_n1":      {"pos": Vector3(-22.0, Y_SUELO, -39.0), "vecinos": ["pasillo_o3"]},
		"aula_n2":      {"pos": Vector3(-14.5, Y_SUELO, -39.0), "vecinos": ["pasillo_o2"]},
		"aula_n3":      {"pos": Vector3(-7.5, Y_SUELO, -39.0),  "vecinos": ["pasillo_o1"]},
		"salon":        {"pos": Vector3(0.0, Y_SUELO, -39.0),   "vecinos": ["cruce"]},
		"aula_n4":      {"pos": Vector3(7.5, Y_SUELO, -39.0),   "vecinos": ["pasillo_e1"]},
		"banos":        {"pos": Vector3(14.5, Y_SUELO, -39.0),  "vecinos": ["pasillo_e2"]},
		"gimnasio":     {"pos": Vector3(22.0, Y_SUELO, -39.0),  "vecinos": ["pasillo_e3"]}
	}

func _ocultar_monstruo() -> void:
	estado_actual = Estado.HIDDEN
	_ruta_puntos.clear()
	if _modelo_raiz and is_instance_valid(_modelo_raiz):
		_modelo_raiz.visible = false
		_modelo_raiz.global_position = Vector3(0.0, -30.0, 0.0)

func _iniciar_aparicion() -> void:
	if not _modelo_raiz or not is_instance_valid(_modelo_raiz) or not _animador:
		return
	estado_actual = Estado.PATROL
	_timer_ronda = duracion_ronda_acecho
	_modelo_raiz.visible = true
	
	var spawn_pos := Vector3(0.0, Y_SUELO, -15.5)
	var jugador := _obtener_jugador()
	if jugador and jugador.global_position.distance_to(spawn_pos) < 3.5:
		spawn_pos = Vector3(0.0, Y_SUELO, -29.0)
	
	_modelo_raiz.global_position = spawn_pos
	_planificar_ruta_hacia(_elegir_sala_aleatoria())
	
	_mostrar_aviso("THE STALKER HAS ENTERED THE SCHOOL")
	if _audio_alerta and is_instance_valid(_audio_alerta):
		_audio_alerta.play()

func _elegir_sala_aleatoria() -> String:
	var claves: Array = _waypoints.keys()
	return claves[_rng.randi() % claves.size()]

func _nodo_mas_cercano(pos: Vector3) -> String:
	var mejor: String = "cruce"
	var mejor_dist: float = 999999.0
	for k: String in _waypoints.keys():
		var d: float = pos.distance_squared_to(_waypoints[k]["pos"])
		if d < mejor_dist:
			mejor_dist = d
			mejor = k
	return mejor

func _planificar_ruta_hacia(destino_key: String) -> void:
	if not _modelo_raiz or not is_instance_valid(_modelo_raiz):
		return
	var inicio: String = _nodo_mas_cercano(_modelo_raiz.global_position)
	var cola: Array[Array] = [[inicio]]
	var visitados: Dictionary = {inicio: true}
	
	while not cola.is_empty():
		var camino: Array = cola.pop_front()
		var actual: String = camino.back()
		if actual == destino_key:
			_ruta_puntos.clear()
			for nodo_k: String in camino:
				_ruta_puntos.append(_waypoints[nodo_k]["pos"])
			return
		for vec: String in _waypoints[actual]["vecinos"]:
			if not visitados.has(vec):
				visitados[vec] = true
				var nuevo_camino: Array = camino.duplicate()
				nuevo_camino.append(vec)
				cola.append(nuevo_camino)

func _physics_process(delta: float) -> void:
	if _timer_aviso > 0.0:
		_timer_aviso -= delta
		if _timer_aviso <= 0.0 and _label_alerta:
			_label_alerta.visible = false
	
	_actualizar_reloj_y_latidos(delta)
	
	if not _modelo_raiz or not is_instance_valid(_modelo_raiz) or not _animador:
		return
	
	if estado_actual == Estado.HIDDEN:
		_timer_estado -= delta
		if _timer_estado <= 0.0:
			_iniciar_aparicion()
		return
	
	if estado_actual == Estado.JUMPSCARE:
		_animador.actualizar(delta, 0.0, true, true)
		return
	
	_timer_ronda -= delta
	if _timer_ronda <= 0.0 and estado_actual != Estado.CHASE:
		_ocultar_monstruo()
		_timer_estado = tiempo_entre_apariciones
		_mostrar_aviso("THE STALKER LEFT THE BUILDING")
		return
	
	var jugador_cuerpo: CharacterBody3D = _obtener_jugador()
	var jugador_a_salvo: bool = _esta_jugador_a_salvo(jugador_cuerpo)
	
	if jugador_cuerpo and not jugador_a_salvo:
		if _puede_ver_jugador(jugador_cuerpo):
			estado_actual = Estado.CHASE
		elif _puede_oir_aspiradora(jugador_cuerpo) and estado_actual != Estado.CHASE:
			estado_actual = Estado.INVESTIGATE
			_planificar_ruta_hacia(_nodo_mas_cercano(jugador_cuerpo.global_position))
	elif jugador_a_salvo and (estado_actual == Estado.CHASE or estado_actual == Estado.INVESTIGATE):
		estado_actual = Estado.STALK_DOOR
		_timer_estado = 6.5
		_planificar_ruta_hacia("lobby_sur")
	
	var vel_aplicada: float = 0.0
	match estado_actual:
		Estado.PATROL:
			vel_aplicada = _seguir_ruta(delta, velocidad_patrulla)
			if _ruta_puntos.is_empty():
				_planificar_ruta_hacia(_elegir_sala_aleatoria())
		Estado.INVESTIGATE:
			vel_aplicada = _seguir_ruta(delta, velocidad_patrulla * 1.45)
			if _ruta_puntos.is_empty():
				estado_actual = Estado.PATROL
		Estado.CHASE:
			if jugador_cuerpo and is_instance_valid(jugador_cuerpo):
				vel_aplicada = _mover_hacia_punto(delta, jugador_cuerpo.global_position, velocidad_persecucion)
				if _modelo_raiz.global_position.distance_to(jugador_cuerpo.global_position) < 1.35:
					_activar_jumpscare(jugador_cuerpo)
					return
		Estado.STALK_DOOR:
			if not _ruta_puntos.is_empty():
				vel_aplicada = _seguir_ruta(delta, velocidad_patrulla * 1.2)
			else:
				vel_aplicada = _mover_hacia_punto(delta, _pos_acecho_puerta, velocidad_patrulla)
				if jugador_cuerpo and is_instance_valid(jugador_cuerpo):
					_mirar_hacia(delta, jugador_cuerpo.global_position)
			_timer_estado -= delta
			if _timer_estado <= 0.0:
				estado_actual = Estado.PATROL
				_planificar_ruta_hacia(_elegir_sala_aleatoria())
	
	_animador.actualizar(delta, vel_aplicada, estado_actual == Estado.CHASE, false)
	_procesar_pasos_audio(delta, vel_aplicada)

func _actualizar_hud_vidas() -> void:
	for i: int in range(_labels_vidas.size()):
		var lbl: Label = _labels_vidas[i]
		if i < vidas_actuales:
			lbl.text = "♥"
			lbl.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25))
		else:
			lbl.text = "♡"
			lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45, 0.7))

func _actualizar_reloj_y_latidos(delta: float) -> void:
	if not _label_reloj or not _label_icono_estado or not _label_corazon:
		return
	
	var bpm: float = 65.0
	var sonar_latido: bool = false
	var color_estado := Color(0.75, 0.75, 0.75)
	
	if estado_actual == Estado.HIDDEN:
		var segs: int = max(0, int(ceil(_timer_estado)))
		var mins: int = segs / 60
		var rem: int = segs % 60
		
		_label_icono_estado.text = "[ -- ] CLEAR"
		_label_reloj.text = "ARRIVES IN %02d:%02d" % [mins, rem]
		
		if _timer_estado <= 10.0:
			var urgencia: float = 1.0 - (_timer_estado / 10.0)
			bpm = lerp(85.0, 145.0, urgencia)
			sonar_latido = true
			color_estado = Color(0.95, 0.72, 0.35)
		else:
			bpm = 65.0
			sonar_latido = false
			color_estado = Color(0.55, 0.88, 0.60)
	else:
		var segs_ronda: int = max(0, int(ceil(_timer_ronda)))
		var mins_r: int = segs_ronda / 60
		var rem_r: int = segs_ronda % 60
		
		if estado_actual == Estado.CHASE:
			_label_icono_estado.text = "[ ((◉)) ] CHASING YOU!"
			_label_reloj.text = "RUN TO JANITOR OFFICE!"
			bpm = 175.0
			color_estado = Color(1.0, 0.25, 0.25)
		elif estado_actual == Estado.INVESTIGATE or estado_actual == Estado.STALK_DOOR:
			_label_icono_estado.text = "[ (◉) ] STALKER ALERT"
			_label_reloj.text = "LEAVES IN %02d:%02d" % [mins_r, rem_r]
			bpm = 145.0
			color_estado = Color(0.98, 0.45, 0.35)
		else:
			_label_icono_estado.text = "[ ◉ ] STALKER INSIDE"
			_label_reloj.text = "LEAVES IN %02d:%02d" % [mins_r, rem_r]
			bpm = 120.0
			color_estado = Color(0.95, 0.38, 0.38)
		
		sonar_latido = true
	
	_label_icono_estado.add_theme_color_override("font_color", color_estado)
	_label_corazon.add_theme_color_override("font_color", color_estado)
	
	var intervalo_latido: float = 60.0 / bpm
	_timer_latido -= delta
	if _timer_latido <= 0.0:
		_timer_latido = intervalo_latido
		_escala_corazon = 1.38
		if sonar_latido and _audio_latido and is_instance_valid(_audio_latido):
			var factor_intensidad: float = clamp((bpm - 80.0) / 95.0, 0.0, 1.0)
			_audio_latido.volume_db = volumen_latido_db + lerp(-5.0, 4.0, factor_intensidad)
			_audio_latido.pitch_scale = lerp(0.92, 1.18, factor_intensidad)
			_audio_latido.play()
	
	_escala_corazon = lerp(_escala_corazon, 1.0, delta * 12.0)
	_label_corazon.pivot_offset = _label_corazon.size * 0.5
	_label_corazon.scale = Vector2(_escala_corazon, _escala_corazon)

func _seguir_ruta(delta: float, vel: float) -> float:
	if _ruta_puntos.is_empty():
		return 0.0
	var objetivo: Vector3 = _ruta_puntos[0]
	var v: float = _mover_hacia_punto(delta, objetivo, vel)
	if _modelo_raiz.global_position.distance_to(objetivo) < 0.55:
		_ruta_puntos.remove_at(0)
	return v

func _mover_hacia_punto(delta: float, destino: Vector3, vel: float) -> float:
	var dest_suelo := Vector3(destino.x, Y_SUELO, destino.z)
	if dest_suelo.x < -3.7 and dest_suelo.x > -11.2 and dest_suelo.z > -26.2 and dest_suelo.z < -12.0:
		dest_suelo.x = -3.4
	
	var diff: Vector3 = dest_suelo - _modelo_raiz.global_position
	diff.y = 0.0
	if diff.length() < 0.08:
		return 0.0
	
	var dir: Vector3 = diff.normalized()
	var sig_pos: Vector3 = _modelo_raiz.global_position + dir * vel * delta
	if sig_pos.x < -3.7 and sig_pos.x > -11.2 and sig_pos.z > -26.2 and sig_pos.z < -12.0:
		return 0.0
	
	_modelo_raiz.global_position = sig_pos
	_mirar_hacia(delta, dest_suelo)
	return vel

func _mirar_hacia(delta: float, punto: Vector3) -> void:
	var dir: Vector3 = punto - _modelo_raiz.global_position
	dir.y = 0.0
	if dir.length_squared() > 0.001:
		var ang_objetivo: float = atan2(dir.x, dir.z)
		_modelo_raiz.rotation.y = lerp_angle(_modelo_raiz.rotation.y, ang_objetivo, delta * 8.0)

func _obtener_jugador() -> CharacterBody3D:
	var lista := get_tree().get_nodes_in_group("jugador")
	if lista.is_empty():
		return null
	return lista[0] as CharacterBody3D

func _esta_jugador_a_salvo(cuerpo: CharacterBody3D) -> bool:
	if not cuerpo or not is_instance_valid(cuerpo):
		return false
	var mapas := get_tree().get_nodes_in_group("mapa_instituto")
	if not mapas.is_empty():
		return mapas[0].es_zona_segura(cuerpo.global_position)
	return false

func _puede_ver_jugador(cuerpo: CharacterBody3D) -> bool:
	if not cuerpo or not is_instance_valid(cuerpo):
		return false
	var origen: Vector3 = _modelo_raiz.global_position + Vector3(0.0, 0.9, 0.0)
	var destino: Vector3 = cuerpo.global_position + Vector3(0.0, 1.1, 0.0)
	var dist: float = origen.distance_to(destino)
	if dist > rango_vision:
		return false
	
	var frente: Vector3 = Vector3(sin(_modelo_raiz.rotation.y), 0.0, cos(_modelo_raiz.rotation.y))
	var dir_a_jugador: Vector3 = (destino - origen).normalized()
	if frente.dot(dir_a_jugador) < 0.35:
		return false
	
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origen, destino)
	query.exclude = [cuerpo.get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	return hit.is_empty()

func _puede_oir_aspiradora(cuerpo: CharacterBody3D) -> bool:
	if not cuerpo or not is_instance_valid(cuerpo):
		return false
	var player_nodo: Node = cuerpo.get_parent()
	if not player_nodo or not ("_aspirando_anterior" in player_nodo):
		return false
	if not player_nodo._aspirando_anterior:
		return false
	return _modelo_raiz.global_position.distance_to(cuerpo.global_position) <= rango_oido_aspiradora

func _activar_jumpscare(cuerpo: CharacterBody3D) -> void:
	estado_actual = Estado.JUMPSCARE
	vidas_actuales = max(0, vidas_actuales - 1)
	_actualizar_hud_vidas()
	
	if _audio_susto and is_instance_valid(_audio_susto):
		_audio_susto.play()
	
	var player_nodo: Node = cuerpo.get_parent()
	if player_nodo and is_instance_valid(player_nodo):
		player_nodo.set_physics_process(false)
	
	var cam := get_viewport().get_camera_3d()
	if cam and is_instance_valid(cam):
		var frente_cam: Vector3 = -cam.global_transform.basis.z
		_modelo_raiz.global_position = cam.global_position + frente_cam * 0.9 - Vector3(0.0, 1.65, 0.0)
		_modelo_raiz.rotation.y = atan2(-frente_cam.x, -frente_cam.z)
	
	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree():
		return
	
	# Si perdió los 3 corazones -> GAME OVER y regreso a pantalla principal conservando el progreso
	if vidas_actuales <= 0:
		_ejecutar_game_over()
		return
	
	# Si aún le quedan corazones -> Escapa herido a la Janitor Office
	if player_nodo and is_instance_valid(player_nodo):
		if "dinero" in player_nodo:
			player_nodo.dinero = int(player_nodo.dinero * 0.5)
			if player_nodo.has_method("_refrescar_hud_jugador"):
				player_nodo._refrescar_hud_jugador()
		if cuerpo and is_instance_valid(cuerpo):
			cuerpo.global_position = Vector3(-7.5, 0.05, -19.0)
		player_nodo.set_physics_process(true)
	
	_ocultar_monstruo()
	_timer_estado = tiempo_entre_apariciones
	_forzar_guardado_web()
	_mostrar_aviso("YOU LOST A HEART! (%d/%d LEFT)" % [vidas_actuales, vidas_maximas])

func _ejecutar_game_over() -> void:
	# Guardamos todo el progreso actual en user://janitor_save.json y restauramos los 3 corazones para al continuar
	vidas_actuales = vidas_maximas
	_forzar_guardado_web()
	
	if _capa_gameover:
		_capa_gameover.visible = true
	
	await get_tree().create_timer(2.4).timeout
	if not is_inside_tree():
		return
	
	if ResourceLoader.exists(ruta_intro):
		get_tree().change_scene_to_file(ruta_intro)
	else:
		push_warning("No se encontró la escena principal: " + ruta_intro)

func _forzar_guardado_web() -> void:
	var guardados := get_tree().get_nodes_in_group("gestor_guardado")
	if not guardados.is_empty() and guardados[0].has_method("guardar_partida"):
		guardados[0].guardar_partida()

func _crear_hud_alerta() -> void:
	var capa := CanvasLayer.new()
	capa.name = "HUD_Monstruo"
	capa.layer = 8
	add_child(capa)
	
	# 1. Panel superior central: Radar + Reloj + 3 Corazones de Vida
	var center_top := CenterContainer.new()
	center_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	center_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(center_top)
	
	var margin_top := MarginContainer.new()
	margin_top.add_theme_constant_override("margin_top", 16)
	center_top.add_child(margin_top)
	
	var vbox_total := VBoxContainer.new()
	vbox_total.add_theme_constant_override("separation", 6)
	vbox_total.alignment = BoxContainer.ALIGNMENT_CENTER
	margin_top.add_child(vbox_total)
	
	_panel_radar = PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.06, 0.06, 0.06, 0.76)
	estilo.set_border_width_all(1)
	estilo.border_color = Color(0.75, 0.75, 0.75, 0.5)
	estilo.set_corner_radius_all(4)
	estilo.set_content_margin_all(10)
	_panel_radar.add_theme_stylebox_override("panel", estilo)
	vbox_total.add_child(_panel_radar)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel_radar.add_child(hbox)
	
	_label_corazon = Label.new()
	_label_corazon.text = "♥"
	_label_corazon.add_theme_font_size_override("font_size", 24)
	_label_corazon.add_theme_color_override("font_color", Color(0.55, 0.88, 0.60))
	hbox.add_child(_label_corazon)
	
	var vbox_info := VBoxContainer.new()
	vbox_info.add_theme_constant_override("separation", 2)
	hbox.add_child(vbox_info)
	
	_label_icono_estado = Label.new()
	_label_icono_estado.text = "[ -- ] CLEAR"
	_label_icono_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_icono_estado.add_theme_font_size_override("font_size", 16)
	_label_icono_estado.add_theme_color_override("font_color", Color(0.55, 0.88, 0.60))
	vbox_info.add_child(_label_icono_estado)
	
	_label_reloj = Label.new()
	_label_reloj.text = "ARRIVES IN 00:35"
	_label_reloj.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_reloj.add_theme_font_size_override("font_size", 14)
	_label_reloj.add_theme_color_override("font_color", Color(0.90, 0.90, 0.90))
	vbox_info.add_child(_label_reloj)
	
	# Fila de los 3 corazones visibles del jugador
	var hbox_vidas := HBoxContainer.new()
	hbox_vidas.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox_vidas.add_theme_constant_override("separation", 10)
	vbox_total.add_child(hbox_vidas)
	
	_labels_vidas.clear()
	for i: int in range(vidas_maximas):
		var lbl_v := Label.new()
		lbl_v.text = "♥"
		lbl_v.add_theme_font_size_override("font_size", 26)
		lbl_v.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25))
		lbl_v.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
		lbl_v.add_theme_constant_override("shadow_offset_x", 2)
		lbl_v.add_theme_constant_override("shadow_offset_y", 2)
		hbox_vidas.add_child(lbl_v)
		_labels_vidas.append(lbl_v)
	
	# 2. Aviso temporal debajo
	var center_aviso := CenterContainer.new()
	center_aviso.set_anchors_preset(Control.PRESET_TOP_WIDE)
	center_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(center_aviso)
	
	var margin_aviso := MarginContainer.new()
	margin_aviso.add_theme_constant_override("margin_top", 122)
	center_aviso.add_child(margin_aviso)
	
	_label_alerta = Label.new()
	_label_alerta.visible = false
	_label_alerta.add_theme_font_size_override("font_size", 26)
	_label_alerta.add_theme_color_override("font_color", Color(0.96, 0.96, 0.96))
	_label_alerta.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	_label_alerta.add_theme_constant_override("shadow_offset_x", 3)
	_label_alerta.add_theme_constant_override("shadow_offset_y", 3)
	margin_aviso.add_child(_label_alerta)
	
	# 3. Pantalla negra de GAME OVER (oculta hasta perder los 3 corazones)
	_capa_gameover = ColorRect.new()
	_capa_gameover.set_anchors_preset(Control.PRESET_FULL_RECT)
	_capa_gameover.color = Color(0.0, 0.0, 0.0, 0.94)
	_capa_gameover.visible = false
	capa.add_child(_capa_gameover)
	
	var center_go := CenterContainer.new()
	center_go.set_anchors_preset(Control.PRESET_FULL_RECT)
	_capa_gameover.add_child(center_go)
	
	var vbox_go := VBoxContainer.new()
	vbox_go.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_go.add_theme_constant_override("separation", 14)
	center_go.add_child(vbox_go)
	
	var lbl_go := Label.new()
	lbl_go.text = "GAME OVER"
	lbl_go.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_go.add_theme_font_size_override("font_size", 64)
	lbl_go.add_theme_color_override("font_color", Color(0.95, 0.22, 0.22))
	vbox_go.add_child(lbl_go)
	
	var lbl_sub := Label.new()
	lbl_sub.text = "ALL HEARTS LOST — PROGRESS SAVED"
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sub.add_theme_font_size_override("font_size", 20)
	lbl_sub.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox_go.add_child(lbl_sub)

func _mostrar_aviso(texto: String) -> void:
	if not _label_alerta:
		return
	_label_alerta.text = texto
	_label_alerta.visible = true
	_timer_aviso = 3.5

func _procesar_pasos_audio(delta: float, vel: float) -> void:
	if vel < 0.2 or not _audio_pasos_monstruo:
		return
	_timer_paso_audio -= delta * (vel * 0.65)
	if _timer_paso_audio <= 0.0:
		_timer_paso_audio = 0.42
		_audio_pasos_monstruo.pitch_scale = _rng.randf_range(0.85, 1.15)
		_audio_pasos_monstruo.play()

func _preparar_audios_monstruo() -> void:
	_audio_latido = AudioStreamPlayer.new()
	_audio_latido.stream = _sintetizar_latido_corazon()
	_audio_latido.volume_db = volumen_latido_db
	add_child(_audio_latido)
	
	_audio_alerta = AudioStreamPlayer.new()
	_audio_alerta.stream = _sintetizar_rugido(0.9, 68.0, 42.0, 0.5)
	_audio_alerta.volume_db = -5.0
	add_child(_audio_alerta)
	
	_audio_susto = AudioStreamPlayer.new()
	_audio_susto.stream = _sintetizar_rugido(1.4, 190.0, 520.0, 0.95)
	_audio_susto.volume_db = -2.0
	add_child(_audio_susto)
	
	_audio_pasos_monstruo = AudioStreamPlayer3D.new()
	_audio_pasos_monstruo.stream = _sintetizar_rugido(0.11, 95.0, 45.0, 0.4)
	_audio_pasos_monstruo.max_distance = 24.0
	_audio_pasos_monstruo.volume_db = -4.0
	add_child(_audio_pasos_monstruo)

func _sintetizar_latido_corazon() -> AudioStreamWAV:
	var dur: float = 0.32
	var muestras: int = int(SAMPLE_RATE * dur)
	var datos := PackedByteArray()
	datos.resize(muestras * 2)
	
	for i: int in range(muestras):
		var t: float = float(i) / float(SAMPLE_RATE)
		var val: float = 0.0
		if t < 0.11:
			var env1: float = sin((t / 0.11) * PI) * exp(-t * 14.0)
			val += sin(TAU * 52.0 * t * (1.0 - t * 2.0)) * env1 * 0.95
		if t >= 0.14 and t < 0.28:
			var t2: float = t - 0.14
			var env2: float = sin((t2 / 0.14) * PI) * exp(-t2 * 16.0)
			val += sin(TAU * 44.0 * t2 * (1.0 - t2 * 2.0)) * env2 * 0.72
		datos.encode_s16(i * 2, int(clamp(val, -1.0, 1.0) * 32767.0))
	
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = datos
	return wav

func _sintetizar_rugido(dur: float, f0: float, f1: float, dist: float) -> AudioStreamWAV:
	var muestras: int = int(SAMPLE_RATE * dur)
	var datos := PackedByteArray()
	datos.resize(muestras * 2)
	var fase: float = 0.0
	for i: int in range(muestras):
		var t: float = float(i) / float(SAMPLE_RATE)
		var p: float = t / dur
		var freq: float = lerp(f0, f1, p) + sin(t * 48.0) * 18.0
		fase += (TAU * freq) / float(SAMPLE_RATE)
		var env: float = clamp(t / 0.04, 0.0, 1.0) * clamp((dur - t) / 0.15, 0.0, 1.0)
		var raw: float = sin(fase) * 0.6 + _rng.randf_range(-1.0, 1.0) * dist * 0.5
		var s: float = tanh(raw * 2.2) * env * 0.75
		datos.encode_s16(i * 2, int(clamp(s, -1.0, 1.0) * 32767.0))
	
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = datos
	return wav
