extends Node3D

@export_file("*.glb", "*.tscn") var ruta_modelo_nube: String = ""
@export_file("*.glb", "*.tscn") var ruta_modelo_personaje: String = ""
@export_file("*.glb", "*.tscn") var ruta_modelo_zeus: String = ""
@export_file("*.tscn") var ruta_intro: String = "res://Intro.tscn"

@export var cantidad_nubes: int = 18
@export var ancho_objetivo_nube: float = 4.2
@export var separacion_nubes: float = 3.0
@export var velocidad_andar: float = 4.4
@export var fuerza_salto: float = 6.8
@export var gravedad: float = 18.0
@export var distancia_camara_lateral: float = 8.5
@export var altura_camara_lateral: float = 1.85
@export var distancia_encuentro_zeus: float = 3.2

const SAMPLE_RATE: int = 22050
const RUTA_SAVE: String = "user://janitor_save.json"

var _player_body: CharacterBody3D
var _visual_personaje: Node3D
var _animador: JanitorAnimador
var _camara: Camera3D

var _zeus_raiz: Node3D
var _zeus_animador: ZeusAnimador
var _zeus_base_pos := Vector3.ZERO
var _luz_divina: OmniLight3D
var _env_cielo: Environment

var _hud_ayuda: CanvasLayer
var _capa_creditos: CanvasLayer
var _vbox_creditos: VBoxContainer
var _btn_volver: Button
var _audio_final: AudioStreamPlayer

var _nubes_data: Array[Dictionary] = []
var _ultima_pos_segura := Vector3(0.0, 2.0, 0.0)
var _direccion_mirada: float = 1.0
var _tiempo_total: float = 0.0
var _final_activado: bool = false
var _tiempo_final: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 77777
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_resolver_rutas_glb()
	_crear_entorno_celestial()
	_generar_camino_nubes_recto()
	_instanciar_personaje()
	_instanciar_zeus_al_final()
	_crear_camara_lateral()
	_crear_hud_ayuda()
	_preparar_audio_celestial()

func _resolver_rutas_glb() -> void:
	var glbs_encontrados: Array[String] = []
	_escanear_glbs("res://", glbs_encontrados)
	
	if ruta_modelo_nube.is_empty() or not ResourceLoader.exists(ruta_modelo_nube):
		for g: String in glbs_encontrados:
			var low: String = g.to_lower()
			if "nube" in low or "cloud" in low:
				ruta_modelo_nube = g
				break
	
	if ruta_modelo_zeus.is_empty() or not ResourceLoader.exists(ruta_modelo_zeus):
		for g: String in glbs_encontrados:
			var low: String = g.to_lower()
			if "zeus" in low or "god" in low or "dios" in low:
				ruta_modelo_zeus = g
				break
	
	if ruta_modelo_personaje.is_empty() or not ResourceLoader.exists(ruta_modelo_personaje):
		for g: String in glbs_encontrados:
			var low: String = g.to_lower()
			if "monstruo" in low or "monster" in low or "stalker" in low or "nube" in low or "cloud" in low or "zeus" in low or "god" in low or "dios" in low:
				continue
			if "janitor" in low or "conserje" in low or "player" in low or "personaje" in low or "leon" in low:
				ruta_modelo_personaje = g
				break
		if ruta_modelo_personaje.is_empty():
			for g: String in glbs_encontrados:
				var low: String = g.to_lower()
				if not ("monstruo" in low or "monster" in low or "nube" in low or "cloud" in low or "zeus" in low or "god" in low or "dios" in low):
					ruta_modelo_personaje = g
					break

func _escanear_glbs(ruta_dir: String, resultado: Array[String]) -> void:
	var dir := DirAccess.open(ruta_dir)
	if not dir:
		return
	dir.list_dir_begin()
	var nombre: String = dir.get_next()
	while nombre != "":
		if not nombre.begins_with("."):
			var full: String = ruta_dir.path_join(nombre)
			if dir.current_is_dir():
				_escanear_glbs(full, resultado)
			elif nombre.to_lower().ends_with(".glb") or nombre.to_lower().ends_with(".gltf"):
				resultado.append(full)
		nombre = dir.get_next()
	dir.list_dir_end()

func _crear_entorno_celestial() -> void:
	var we := WorldEnvironment.new()
	_env_cielo = Environment.new()
	_env_cielo.background_mode = Environment.BG_COLOR
	_env_cielo.background_color = Color(0.68, 0.72, 0.78)
	_env_cielo.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env_cielo.ambient_light_color = Color(0.85, 0.88, 0.92)
	_env_cielo.ambient_light_energy = 0.95
	
	_env_cielo.fog_enabled = true
	_env_cielo.fog_light_color = Color(0.72, 0.76, 0.82)
	_env_cielo.fog_density = 0.014
	we.environment = _env_cielo
	add_child(we)
	
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	sol.light_energy = 1.4
	sol.shadow_enabled = true
	add_child(sol)

func _generar_camino_nubes_recto() -> void:
	var packed_nube: PackedScene = null
	if not ruta_modelo_nube.is_empty() and ResourceLoader.exists(ruta_modelo_nube):
		packed_nube = load(ruta_modelo_nube)
	
	var contenedor_nubes := Node3D.new()
	contenedor_nubes.name = "CaminoNubes"
	add_child(contenedor_nubes)
	
	var x_actual: float = 0.0
	var y_recta: float = 0.0
	
	for i: int in range(cantidad_nubes):
		var nodo_nube := StaticBody3D.new()
		nodo_nube.name = "NubePlataforma_" + str(i)
		nodo_nube.position = Vector3(x_actual, y_recta, 0.0)
		contenedor_nubes.add_child(nodo_nube)
		
		var superficie_top_y: float = 0.45
		
		if packed_nube:
			var pivot_modelo := Node3D.new()
			nodo_nube.add_child(pivot_modelo)
			
			var modelo: Node3D = packed_nube.instantiate()
			if i % 2 == 1:
				modelo.rotation.y = PI
			pivot_modelo.add_child(modelo)
			_asegurar_visibilidad_mallas(modelo)
			
			var aabb := _calcular_aabb_recursivo(modelo)
			var max_lado: float = max(aabb.size.x, max(aabb.size.y, aabb.size.z))
			if max_lado > 0.0001:
				var factor_norm: float = ancho_objetivo_nube / max_lado
				pivot_modelo.scale = Vector3.ONE * factor_norm
				modelo.position = -aabb.get_center()
				superficie_top_y = (aabb.size.y * 0.5) * factor_norm
			
			_generar_colision_suave_nube(nodo_nube, pivot_modelo)
		else:
			_crear_nube_voxel_respaldo(nodo_nube)
		
		_nubes_data.append({
			"nodo": nodo_nube,
			"x": x_actual,
			"base_y": y_recta,
			"fase": float(i) * 0.7,
			"superficie_y": y_recta + superficie_top_y
		})
		
		x_actual += separacion_nubes

func _generar_colision_suave_nube(cuerpo_estatico: StaticBody3D, raiz_visual: Node3D) -> void:
	var mallas: Array[MeshInstance3D] = []
	_recolectar_mesh_instances(raiz_visual, mallas)
	
	for mi: MeshInstance3D in mallas:
		if not mi.mesh:
			continue
		var shape: ConvexPolygonShape3D = mi.mesh.create_convex_shape(true, true)
		if not shape:
			continue
		var col := CollisionShape3D.new()
		col.shape = shape
		col.transform = cuerpo_estatico.global_transform.affine_inverse() * mi.global_transform
		cuerpo_estatico.add_child(col)

func _recolectar_mesh_instances(nodo: Node, lista: Array[MeshInstance3D]) -> void:
	if nodo is MeshInstance3D:
		lista.append(nodo)
	for hijo: Node in nodo.get_children():
		_recolectar_mesh_instances(hijo, lista)

func _crear_nube_voxel_respaldo(padre: StaticBody3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.96, 0.97, 0.99)
	mat.roughness = 0.85
	var bloques: Array[Array] = [
		[Vector3(3.8, 0.65, 2.4), Vector3(0.0, 0.0, 0.0)],
		[Vector3(2.4, 0.55, 1.8), Vector3(-0.2, 0.45, 0.1)],
		[Vector3(1.6, 0.45, 1.4), Vector3(0.65, 0.35, -0.15)]
	]
	for b: Array in bloques:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = b[0]
		mi.mesh = box
		mi.position = b[1]
		mi.material_override = mat
		padre.add_child(mi)
	_generar_colision_suave_nube(padre, padre)

func _asegurar_visibilidad_mallas(nodo: Node) -> void:
	if nodo is MeshInstance3D:
		nodo.visible = true
		var mat_existente: Material = nodo.get_active_material(0)
		if mat_existente == null:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.96, 0.97, 0.99)
			mat.roughness = 0.85
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			nodo.material_override = mat
		elif mat_existente is StandardMaterial3D:
			var dup := mat_existente.duplicate() as StandardMaterial3D
			dup.cull_mode = BaseMaterial3D.CULL_DISABLED
			nodo.material_override = dup
	for hijo: Node in nodo.get_children():
		_asegurar_visibilidad_mallas(hijo)

func _calcular_aabb_recursivo(nodo: Node) -> AABB:
	var total := AABB()
	var primero: bool = true
	if nodo is VisualInstance3D:
		total = nodo.get_aabb()
		primero = false
	for hijo: Node in nodo.get_children():
		var sub := _calcular_aabb_recursivo(hijo)
		if sub.size.length_squared() > 0.0001:
			if primero:
				total = sub
				primero = false
			else:
				total = total.merge(sub)
	return total

func _instanciar_personaje() -> void:
	_player_body = CharacterBody3D.new()
	_player_body.name = "JugadorCielo"
	_player_body.floor_max_angle = deg_to_rad(70.0)
	_player_body.floor_snap_length = 0.45
	_player_body.floor_constant_speed = true
	_player_body.floor_stop_on_slope = false
	_player_body.safe_margin = 0.02
	
	var y_inicio: float = 1.2
	if not _nubes_data.is_empty():
		y_inicio = _nubes_data[0]["superficie_y"] + 0.25
	_player_body.position = Vector3(0.0, y_inicio, 0.0)
	_ultima_pos_segura = _player_body.position
	add_child(_player_body)
	
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.65
	col.shape = cap
	col.position = Vector3(0.0, 0.825, 0.0)
	_player_body.add_child(col)
	
	_visual_personaje = Node3D.new()
	_visual_personaje.name = "VisualPersonaje"
	_visual_personaje.rotation.y = PI * 0.5
	_player_body.add_child(_visual_personaje)
	
	if not ruta_modelo_personaje.is_empty() and ResourceLoader.exists(ruta_modelo_personaje):
		var packed_pj: PackedScene = load(ruta_modelo_personaje)
		var instancia: Node3D = packed_pj.instantiate()
		_visual_personaje.add_child(instancia)
		
		var skel := _buscar_skeleton(instancia)
		if skel:
			_animador = JanitorAnimador.new(skel)

func _instanciar_zeus_al_final() -> void:
	var x_final: float = float(max(0, cantidad_nubes - 1)) * separacion_nubes
	var y_superficie: float = 0.5
	if not _nubes_data.is_empty():
		var ultima: Dictionary = _nubes_data.back()
		x_final = ultima["x"]
		y_superficie = ultima["superficie_y"]
	
	_zeus_base_pos = Vector3(x_final, y_superficie + 0.85, 0.0)
	
	_zeus_raiz = Node3D.new()
	_zeus_raiz.name = "ZeusFlotante"
	_zeus_raiz.position = _zeus_base_pos
	_zeus_raiz.rotation.y = -PI * 0.5
	add_child(_zeus_raiz)
	
	_luz_divina = OmniLight3D.new()
	_luz_divina.position = Vector3(0.0, 1.8, 0.9)
	_luz_divina.light_color = Color(1.0, 0.97, 0.86)
	_luz_divina.light_energy = 2.4
	_luz_divina.omni_range = 8.5
	_zeus_raiz.add_child(_luz_divina)
	
	if not ruta_modelo_zeus.is_empty() and ResourceLoader.exists(ruta_modelo_zeus):
		var packed_zeus: PackedScene = load(ruta_modelo_zeus)
		var instancia_zeus: Node3D = packed_zeus.instantiate()
		_zeus_raiz.add_child(instancia_zeus)
		
		var skel_zeus := _buscar_skeleton(instancia_zeus)
		if skel_zeus:
			_zeus_animador = ZeusAnimador.new(skel_zeus)

func _buscar_skeleton(nodo: Node) -> Skeleton3D:
	if nodo is Skeleton3D:
		return nodo
	for c: Node in nodo.get_children():
		var res := _buscar_skeleton(c)
		if res:
			return res
	return null

func _crear_camara_lateral() -> void:
	_camara = Camera3D.new()
	_camara.name = "SideCamera"
	_camara.fov = 52.0
	_camara.position = _player_body.position + Vector3(1.8, altura_camara_lateral, distancia_camara_lateral)
	add_child(_camara)
	_camara.make_current()

func _physics_process(delta: float) -> void:
	_tiempo_total += delta
	_animar_flotacion_nubes(delta)
	_animar_zeus(delta)
	
	if not _player_body:
		return
	
	if _final_activado:
		_procesar_secuencia_final_zeus(delta)
		return
	
	if not _player_body.is_on_floor():
		_player_body.velocity.y -= gravedad * delta
	else:
		_ultima_pos_segura = _player_body.global_position + Vector3(0.0, 0.4, 0.0)
		if Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			_player_body.velocity.y = fuerza_salto
	
	var dir_x: float = 0.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir_x += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir_x -= 1.0
	
	_player_body.velocity.x = lerp(_player_body.velocity.x, dir_x * velocidad_andar, delta * 14.0)
	_player_body.velocity.z = 0.0
	_player_body.global_position.z = 0.0
	
	_player_body.move_and_slide()
	
	if abs(dir_x) > 0.1:
		_direccion_mirada = sign(dir_x)
	var rot_objetivo: float = (PI * 0.5) if _direccion_mirada > 0.0 else (-PI * 0.5)
	if _visual_personaje:
		_visual_personaje.rotation.y = lerp_angle(_visual_personaje.rotation.y, rot_objetivo, delta * 12.0)
	
	if _animador:
		_animador.actualizar(delta, _player_body.velocity.x, _player_body.is_on_floor())
	
	if _player_body.global_position.y < -6.0:
		_player_body.velocity = Vector3.ZERO
		_player_body.global_position = _ultima_pos_segura
	
	# Comprobamos si hemos llegado hasta Zeus al final del camino
	if _zeus_raiz and abs(_player_body.global_position.x - _zeus_base_pos.x) <= distancia_encuentro_zeus:
		_iniciar_final_bueno_zeus()
		return
	
	if _camara:
		var adelanto_x: float = _direccion_mirada * 1.65
		var destino_cam := Vector3(
			_player_body.global_position.x + adelanto_x,
			_player_body.global_position.y + altura_camara_lateral,
			distancia_camara_lateral
		)
		_camara.global_position = _camara.global_position.lerp(destino_cam, delta * 5.5)
		_camara.look_at(_player_body.global_position + Vector3(adelanto_x * 0.6, 1.15, 0.0), Vector3.UP)

func _iniciar_final_bueno_zeus() -> void:
	_final_activado = true
	_tiempo_final = 0.0
	_player_body.velocity = Vector3.ZERO
	
	# Borramos la partida guardada porque el turno ha llegado a su desenlace definitivo
	if FileAccess.file_exists(RUTA_SAVE):
		DirAccess.remove_absolute(RUTA_SAVE)
	
	if _hud_ayuda:
		_hud_ayuda.visible = false
	
	if _audio_final and is_instance_valid(_audio_final):
		_audio_final.play()
	
	_crear_capa_creditos_final_bueno()

func _procesar_secuencia_final_zeus(delta: float) -> void:
	_tiempo_final += delta
	
	# El conserje queda en paz mirando hacia Zeus
	if not _player_body.is_on_floor():
		_player_body.velocity.y -= gravedad * delta
	else:
		_player_body.velocity.y = 0.0
	_player_body.velocity.x = lerp(_player_body.velocity.x, 0.0, delta * 8.0)
	_player_body.move_and_slide()
	
	if _visual_personaje:
		_visual_personaje.rotation.y = lerp_angle(_visual_personaje.rotation.y, PI * 0.5, delta * 6.0)
	if _animador:
		_animador.actualizar(delta, _player_body.velocity.x, _player_body.is_on_floor())
	
	# Paneo cinematográfico suave de la cámara hacia Zeus en primer plano
	if _camara and _zeus_raiz:
		var destino_cam := Vector3(
			_zeus_base_pos.x - 1.1,
			_zeus_base_pos.y + 1.35,
			4.8
		)
		var objetivo_mirada := _zeus_raiz.global_position + Vector3(0.0, 1.1, 0.0)
		_camara.global_position = _camara.global_position.lerp(destino_cam, delta * 1.4)
		
		var transf_deseada: Transform3D = _camara.global_transform.looking_at(objetivo_mirada, Vector3.UP)
		_camara.global_transform = _camara.global_transform.interpolate_with(transf_deseada, delta * 2.2)
	
	# La luz divina y el cielo se vuelven aún más luminosos y serenos
	if _luz_divina:
		_luz_divina.light_energy = lerp(_luz_divina.light_energy, 4.2, delta * 0.8)
	if _env_cielo:
		_env_cielo.background_color = _env_cielo.background_color.lerp(Color(0.92, 0.93, 0.96), delta * 0.45)
		_env_cielo.fog_light_color = _env_cielo.fog_light_color.lerp(Color(0.94, 0.95, 0.98), delta * 0.45)
	
	# Tras 2.2 segundos de paneo hacia Zeus, aparecen y suben los créditos
	if _capa_creditos and _tiempo_final >= 2.2:
		_capa_creditos.visible = true
		if _vbox_creditos:
			var alto_vp: float = get_viewport().get_visible_rect().size.y
			var y_limite: float = alto_vp * 0.16
			if _vbox_creditos.position.y > y_limite:
				_vbox_creditos.position.y -= 38.0 * delta
			elif _btn_volver:
				_btn_volver.visible = true

func _crear_capa_creditos_final_bueno() -> void:
	_capa_creditos = CanvasLayer.new()
	_capa_creditos.layer = 12
	_capa_creditos.visible = false
	add_child(_capa_creditos)
	
	# Velo luminoso y sereno semitransparente para leer bien sobre Zeus
	var fondo := ColorRect.new()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.04, 0.05, 0.08, 0.48)
	_capa_creditos.add_child(fondo)
	
	var alto_vp: float = get_viewport().get_visible_rect().size.y
	var ancho_vp: float = get_viewport().get_visible_rect().size.x
	
	_vbox_creditos = VBoxContainer.new()
	_vbox_creditos.custom_minimum_size = Vector2(ancho_vp, 0.0)
	_vbox_creditos.position = Vector2(0.0, alto_vp * 0.72)
	_vbox_creditos.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox_creditos.add_theme_constant_override("separation", 22)
	_capa_creditos.add_child(_vbox_creditos)
	
	var lineas: Array[Array] = [
		["GOOD ENDING — ETERNAL PEACE", 36, Color(1.0, 0.96, 0.80)],
		["", 14, Color.WHITE],
		["THE MOP IS LAID TO REST.", 22, Color(0.95, 0.95, 0.95)],
		["BEYOND THE CLOUDS, BEFORE ZEUS,", 22, Color(0.95, 0.95, 0.95)],
		["YOU REST IN PEACE FOREVER,", 24, Color(1.0, 0.98, 0.88)],
		["WRAPPED IN SUPREME HAPPINESS.", 24, Color(1.0, 0.98, 0.88)],
		["", 24, Color.WHITE],
		["JANITOR ACTIVITIES", 30, Color(0.95, 0.95, 0.95)],
		["THANK YOU FOR PLAYING", 20, Color(0.82, 0.84, 0.88)]
	]
	
	for item: Array in lineas:
		var lbl := Label.new()
		lbl.text = item[0]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", item[1])
		lbl.add_theme_color_override("font_color", item[2])
		lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
		lbl.add_theme_constant_override("shadow_offset_x", 3)
		lbl.add_theme_constant_override("shadow_offset_y", 3)
		_vbox_creditos.add_child(lbl)
	
	var margen_btn := MarginContainer.new()
	margen_btn.add_theme_constant_override("margin_top", 26)
	_vbox_creditos.add_child(margen_btn)
	
	var center_btn := CenterContainer.new()
	margen_btn.add_child(center_btn)
	
	_btn_volver = Button.new()
	_btn_volver.text = "  VOLVER AL MENÚ  "
	_btn_volver.visible = false
	_btn_volver.custom_minimum_size = Vector2(260, 50)
	_btn_volver.add_theme_font_size_override("font_size", 20)
	_btn_volver.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var st_norm := StyleBoxFlat.new()
	st_norm.bg_color = Color(0.06, 0.06, 0.08, 0.88)
	st_norm.set_border_width_all(2)
	st_norm.border_color = Color(1.0, 0.95, 0.78)
	
	var st_hov := st_norm.duplicate()
	st_hov.bg_color = Color(1.0, 0.95, 0.78, 0.95)
	
	_btn_volver.add_theme_stylebox_override("normal", st_norm)
	_btn_volver.add_theme_stylebox_override("hover", st_hov)
	_btn_volver.add_theme_stylebox_override("pressed", st_hov)
	_btn_volver.add_theme_color_override("font_color", Color(1.0, 0.96, 0.84))
	_btn_volver.add_theme_color_override("font_hover_color", Color(0.05, 0.05, 0.05))
	_btn_volver.pressed.connect(func() -> void:
		if ResourceLoader.exists(ruta_intro):
			get_tree().change_scene_to_file(ruta_intro)
	)
	center_btn.add_child(_btn_volver)

func _animar_zeus(delta: float) -> void:
	if _zeus_raiz and is_instance_valid(_zeus_raiz):
		_zeus_raiz.position.y = _zeus_base_pos.y + sin(_tiempo_total * 2.2) * 0.16
		_zeus_raiz.position.x = _zeus_base_pos.x + cos(_tiempo_total * 1.3) * 0.06
	if _zeus_animador:
		_zeus_animador.actualizar(delta)

func _animar_flotacion_nubes(_delta: float) -> void:
	var t: float = float(Time.get_ticks_msec()) * 0.001
	for d: Dictionary in _nubes_data:
		var nodo: StaticBody3D = d["nodo"]
		if is_instance_valid(nodo):
			nodo.position.y = d["base_y"] + sin(t * 1.4 + d["fase"]) * 0.025

func _crear_hud_ayuda() -> void:
	_hud_ayuda = CanvasLayer.new()
	_hud_ayuda.layer = 8
	add_child(_hud_ayuda)
	
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	_hud_ayuda.add_child(margin)
	
	var lbl := Label.new()
	lbl.text = "[A / D] WALK ON CLOUDS   |   [SPACE] JUMP"
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.15, 0.17, 0.22))
	margin.add_child(lbl)

func _preparar_audio_celestial() -> void:
	_audio_final = AudioStreamPlayer.new()
	_audio_final.stream = _sintetizar_acorde_celestial()
	_audio_final.volume_db = -5.0
	add_child(_audio_final)

func _sintetizar_acorde_celestial() -> AudioStreamWAV:
	var dur: float = 5.5
	var muestras: int = int(SAMPLE_RATE * dur)
	var datos := PackedByteArray()
	datos.resize(muestras * 2)
	
	# Acorde mayor luminoso (Do4, Mi4, Sol4, Si4, Re5, Sol5) con ataque suave y cola larga
	var freqs: Array[float] = [261.63, 329.63, 392.00, 493.88, 587.33, 783.99]
	for i: int in range(muestras):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = clamp(t / 1.1, 0.0, 1.0) * clamp((dur - t) / 1.8, 0.0, 1.0)
		var suma: float = 0.0
		for j: int in range(freqs.size()):
			var vibrato: float = sin(t * (2.5 + float(j) * 0.4)) * 0.8
			suma += sin(TAU * (freqs[j] + vibrato) * t) / float(freqs.size())
		var s: float = suma * env * 0.75
		datos.encode_s16(i * 2, int(clamp(s, -1.0, 1.0) * 32767.0))
	
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = datos
	return wav
