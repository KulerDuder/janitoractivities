extends Node3D

@export var radio_anillo: float = 42.0        # Radio exacto del círculo perfecto alrededor del instituto
@export var arboles_fila_1: int = 110         # Fila interior del círculo perfecto
@export var arboles_fila_2: int = 110         # Fila exterior intercalada para tapar huecos
@export var sectores_culling: int = 12        # Divide el círculo en 12 arcos de 30° para descartar lo que no ves
@export var ocultar_en_interior: bool = true  # Apaga el bosque en aulas cerradas (0 gasto en interior)
@export var bloquear_paso_fisico: bool = true # Impide atravesar el círculo de árboles

@export var activar_final_al_tocar: bool = true
@export_file("*.tscn") var ruta_final_bosque: String = "res://FinalBosque.tscn"

const CENTRO_INSTITUTO := Vector3(0.0, 0.0, -29.0)

var _sectores: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()
var _final_disparado: bool = false

func _ready() -> void:
	_rng.seed = 42424
	_generar_circulo_bosque()
	if bloquear_paso_fisico:
		_crear_colision_circular_ligera()
	if activar_final_al_tocar:
		_crear_trigger_final_bosque()
	call_deferred("_conectar_zonas")

func _conectar_zonas() -> void:
	if not ocultar_en_interior:
		return
	var raiz := get_tree().current_scene
	if not raiz:
		return
	for hijo: Node in raiz.get_children():
		if "zona_actual" in hijo and hijo.has_signal("zona_cambiada"):
			hijo.zona_cambiada.connect(_al_cambiar_zona)
			_al_cambiar_zona(hijo.zona_actual, hijo.jugador_a_salvo)
			break

func _al_cambiar_zona(nombre_zona: String, _es_segura: bool) -> void:
	if not ocultar_en_interior:
		return
	var visible_ahora: bool = (nombre_zona == "Outside" or nombre_zona == "Main Hallway (Lobby)")
	for s: Node3D in _sectores:
		s.visible = visible_ahora

func _generar_circulo_bosque() -> void:
	var datos_sectores: Array[Dictionary] = []
	for i: int in range(sectores_culling):
		var nodo_sector := Node3D.new()
		nodo_sector.name = "ArcoBosque_" + str(i)
		add_child(nodo_sector)
		_sectores.append(nodo_sector)
		datos_sectores.append({
			"nodo": nodo_sector,
			"troncos_t": [],
			"troncos_c": [],
			"copas_t": [],
			"copas_c": [],
			"min_p": Vector3(INF, INF, INF),
			"max_p": Vector3(-INF, -INF, -INF)
		})
	
	# 1. Fila interior: círculo perfecto a radio_anillo
	for i: int in range(arboles_fila_1):
		var ang: float = (TAU / float(arboles_fila_1)) * float(i)
		var px: float = CENTRO_INSTITUTO.x + cos(ang) * radio_anillo
		var pz: float = CENTRO_INSTITUTO.z + sin(ang) * radio_anillo
		var sector_idx: int = int(floor((ang / TAU) * float(sectores_culling))) % sectores_culling
		_agregar_arbol_voxel(datos_sectores[sector_idx], px, pz, ang, 0)
	
	# 2. Fila exterior intercalada (+2.2m hacia fuera, desfasada medio paso para tapar huecos entre troncos)
	var paso_ang: float = TAU / float(arboles_fila_2)
	var radio_ext: float = radio_anillo + 2.2
	for i: int in range(arboles_fila_2):
		var ang: float = paso_ang * (float(i) + 0.5)
		var px: float = CENTRO_INSTITUTO.x + cos(ang) * radio_ext
		var pz: float = CENTRO_INSTITUTO.z + sin(ang) * radio_ext
		var sector_idx: int = int(floor((ang / TAU) * float(sectores_culling))) % sectores_culling
		_agregar_arbol_voxel(datos_sectores[sector_idx], px, pz, ang, 1)
	
	# 3. Tercera fila de abetos bajos frondosos (+4.1m) que tapan los huecos bajos entre troncos
	var radio_fondo: float = radio_anillo + 4.1
	for i: int in range(arboles_fila_1):
		var ang: float = (TAU / float(arboles_fila_1)) * float(i)
		var px: float = CENTRO_INSTITUTO.x + cos(ang) * radio_fondo
		var pz: float = CENTRO_INSTITUTO.z + sin(ang) * radio_fondo
		var sector_idx: int = int(floor((ang / TAU) * float(sectores_culling))) % sectores_culling
		_agregar_arbol_voxel(datos_sectores[sector_idx], px, pz, ang, 2)
	
	# Compilar MultiMesh por sector con AABB estricto
	var mesh_cubo := BoxMesh.new()
	mesh_cubo.size = Vector3.ONE
	
	var mat_voxel := StandardMaterial3D.new()
	mat_voxel.vertex_color_use_as_albedo = true
	mat_voxel.roughness = 0.94
	
	for sec: Dictionary in datos_sectores:
		var nodo: Node3D = sec["nodo"]
		if sec["troncos_t"].is_empty() and sec["copas_t"].is_empty():
			continue
		var aabb_sector := AABB(sec["min_p"], sec["max_p"] - sec["min_p"])
		if not sec["troncos_t"].is_empty():
			_crear_mmi(nodo, mesh_cubo, mat_voxel, sec["troncos_t"], sec["troncos_c"], aabb_sector, "Troncos")
		if not sec["copas_t"].is_empty():
			_crear_mmi(nodo, mesh_cubo, mat_voxel, sec["copas_t"], sec["copas_c"], aabb_sector, "Copas")

func _agregar_arbol_voxel(sec: Dictionary, px: float, pz: float, ang_radial: float, capa: int) -> void:
	var basis_base := Basis(Vector3.UP, -ang_radial)
	
	if capa == 2:
		# Capa de fondo: abetos bajos frondosos desde el suelo (tapan el hueco entre troncos con forma de árbol real)
		var ew: float = _rng.randf_range(1.05, 1.35)
		var eh: float = _rng.randf_range(0.95, 1.30)
		var tono_f: float = _rng.randf_range(0.14, 0.22)
		var col_f := Color(tono_f * 0.78, tono_f, tono_f * 0.75)
		
		var bloques_fondo: Array[Array] = [
			[1.1 * eh, 2.8 * ew, 2.2 * eh],
			[2.7 * eh, 2.0 * ew, 1.6 * eh],
			[4.0 * eh, 1.2 * ew, 1.2 * eh]
		]
		for bf: Array in bloques_fondo:
			var b := basis_base.scaled(Vector3(bf[1], bf[2], bf[1]))
			sec["copas_t"].append(Transform3D(b, Vector3(px, bf[0], pz)))
			sec["copas_c"].append(col_f)
		
		var r_f: float = 1.5 * ew
		sec["min_p"] = sec["min_p"].min(Vector3(px - r_f, 0.0, pz - r_f))
		sec["max_p"] = sec["max_p"].max(Vector3(px + r_f, 4.7 * eh, pz + r_f))
		return
	
	var es_fila_trasera: bool = (capa == 1)
	var escala_h: float = _rng.randf_range(0.95, 1.35) if not es_fila_trasera else _rng.randf_range(1.15, 1.50)
	var escala_w: float = _rng.randf_range(1.0, 1.25)
	
	# Tronco vóxel
	var alto_tronco: float = 2.5 * escala_h
	var grosor_tronco: float = 0.54 * escala_w
	var b_tronco := basis_base.scaled(Vector3(grosor_tronco, alto_tronco, grosor_tronco))
	sec["troncos_t"].append(Transform3D(b_tronco, Vector3(px, alto_tronco * 0.5, pz)))
	
	var tono_t: float = _rng.randf_range(0.15, 0.22)
	sec["troncos_c"].append(Color(tono_t + 0.03, tono_t, tono_t - 0.02))
	
	# Copa vóxel escalonada (3 niveles)
	var tono_c: float = _rng.randf_range(0.22, 0.36) if not es_fila_trasera else _rng.randf_range(0.16, 0.25)
	var col_copa := Color(tono_c * 0.78, tono_c, tono_c * 0.75)
	
	var niveles: Array[Array] = [
		[alto_tronco + 0.45 * escala_h, 2.5 * escala_w, 1.3 * escala_h],
		[alto_tronco + 1.55 * escala_h, 1.7 * escala_w, 1.2 * escala_h],
		[alto_tronco + 2.55 * escala_h, 0.95 * escala_w, 1.0 * escala_h]
	]
	
	for niv: Array in niveles:
		var b_c := basis_base.scaled(Vector3(niv[1], niv[2], niv[1]))
		sec["copas_t"].append(Transform3D(b_c, Vector3(px, niv[0], pz)))
		sec["copas_c"].append(col_copa)
	
	var r_max: float = 1.35 * escala_w
	var y_max: float = alto_tronco + 3.2 * escala_h
	sec["min_p"] = sec["min_p"].min(Vector3(px - r_max, 0.0, pz - r_max))
	sec["max_p"] = sec["max_p"].max(Vector3(px + r_max, y_max, pz + r_max))

func _crear_mmi(padre: Node3D, mesh: Mesh, mat: Material, transforms: Array, colores: Array, aabb: AABB, nombre: String) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	
	for i: int in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colores[i])
	
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nombre
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.custom_aabb = aabb
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(mmi)

func _crear_colision_circular_ligera() -> void:
	var sb := StaticBody3D.new()
	sb.name = "ColisionBosqueCircular"
	add_child(sb)
	
	var segmentos: int = 24
	var radio_col: float = radio_anillo - 0.4
	var largo_seg: float = (TAU * radio_col) / float(segmentos) * 1.1
	
	for i: int in range(segmentos):
		var ang: float = (TAU / float(segmentos)) * float(i)
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, 4.0, largo_seg)
		col.shape = box
		col.position = Vector3(
			CENTRO_INSTITUTO.x + cos(ang) * radio_col,
			2.0,
			CENTRO_INSTITUTO.z + sin(ang) * radio_col
		)
		col.rotation.y = -ang
		sb.add_child(col)

func _crear_trigger_final_bosque() -> void:
	var area := Area3D.new()
	area.name = "TriggerFinalBosque"
	area.monitoring = true
	area.monitorable = false
	add_child(area)
	
	var segmentos: int = 24
	var radio_trigger: float = radio_anillo - 0.9
	var largo_seg: float = (TAU * radio_trigger) / float(segmentos) * 1.15
	
	for i: int in range(segmentos):
		var ang: float = (TAU / float(segmentos)) * float(i)
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.2, 4.0, largo_seg)
		col.shape = box
		col.position = Vector3(
			CENTRO_INSTITUTO.x + cos(ang) * radio_trigger,
			2.0,
			CENTRO_INSTITUTO.z + sin(ang) * radio_trigger
		)
		col.rotation.y = -ang
		area.add_child(col)
	
	area.body_entered.connect(func(body: Node3D) -> void:
		if not _final_disparado and body.is_in_group("jugador"):
			_final_disparado = true
			if ResourceLoader.exists(ruta_final_bosque):
				get_tree().call_deferred("change_scene_to_file", ruta_final_bosque)
			else:
				push_warning("Aún no has guardado la escena: " + ruta_final_bosque)
	)
