extends Node

const RUTA_SAVE: String = "user://janitor_save.json"

@export var intervalo_autoguardado: float = 8.0
@export var reaparecer_en_oficina: bool = true # Evita cargar justo encima del monstruo

var _timer_save: float = 0.0
var _cargando: bool = false

func _ready() -> void:
	add_to_group("gestor_guardado")
	call_deferred("_iniciar_restauracion")

func _iniciar_restauracion() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if FileAccess.file_exists(RUTA_SAVE):
		cargar_partida()

func _process(delta: float) -> void:
	if _cargando:
		return
	_timer_save += delta
	if _timer_save >= intervalo_autoguardado:
		_timer_save = 0.0
		guardar_partida()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		guardar_partida()

func guardar_partida() -> void:
	var datos: Dictionary = {
		"version": 1,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# 1. Jugador (dinero, energía y posición)
	var jugadores := get_tree().get_nodes_in_group("jugador")
	if not jugadores.is_empty():
		var cuerpo: CharacterBody3D = jugadores[0]
		var player_nodo: Node = cuerpo.get_parent()
		if player_nodo:
			datos["dinero"] = player_nodo.get("dinero")
			datos["energia"] = player_nodo.get("energia")
		datos["pos_x"] = cuerpo.global_position.x
		datos["pos_y"] = cuerpo.global_position.y
		datos["pos_z"] = cuerpo.global_position.z
	
	# 2. Vidas restantes (corazones)
	var monstruos := get_tree().get_nodes_in_group("gestor_monstruo")
	if not monstruos.is_empty():
		datos["vidas"] = monstruos[0].get("vidas_actuales")
	
	# 3. Aspiradora (nivel de evolución y estadísticas)
	var aspiradoras := get_tree().get_nodes_in_group("aspiradora")
	if not aspiradoras.is_empty():
		var asp: Node = aspiradoras[0]
		datos["nivel_aspiradora"] = asp.get("nivel_mejora")
		datos["rate_aspirado"] = asp.get("rate_aspirado")
		datos["radio_aspirado"] = asp.get("radio_aspirado")
		datos["alcance_aspirado"] = asp.get("alcance_aspirado")
	
	# 4. Power-Ups recogidos
	var raiz := get_tree().current_scene
	if raiz:
		var nodo_pu := raiz.find_child("PowerUps", true, false)
		if nodo_pu and "_items" in nodo_pu:
			var pu_recogidos: Array[int] = []
			var items: Array = nodo_pu.get("_items")
			for i: int in range(items.size()):
				if items[i].get("recogido", false):
					pu_recogidos.append(i)
			datos["powerups_recogidos"] = pu_recogidos
	
	# 5. Suciedad aspirada
	var gestores_suc := get_tree().get_nodes_in_group("gestor_suciedad")
	if not gestores_suc.is_empty():
		var gs: Node = gestores_suc[0]
		var estados: PackedByteArray = gs.get("_estados")
		var recogidos_idx: Array[int] = []
		for i: int in range(estados.size()):
			if estados[i] == 2 or estados[i] == 1:
				recogidos_idx.append(i)
		datos["voxels_recogidos"] = recogidos_idx
	
	# 6. Filosofía
	var gestores_filo := get_tree().get_nodes_in_group("gestor_filosofia")
	if not gestores_filo.is_empty():
		var gf: Node = gestores_filo[0]
		datos["filo_indice"] = gf.get("_indice_actual")
		datos["filo_respuestas"] = gf.get("respuestas_jugador")
	
	var f := FileAccess.open(RUTA_SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(datos))
		f.close()

func cargar_partida() -> void:
	if not FileAccess.file_exists(RUTA_SAVE):
		return
	var f := FileAccess.open(RUTA_SAVE, FileAccess.READ)
	if not f:
		return
	var texto: String = f.get_as_text()
	f.close()
	
	var json := JSON.new()
	if json.parse(texto) != OK or not (json.data is Dictionary):
		return
	var datos: Dictionary = json.data
	_cargando = true
	
	# 1. Restaurar Jugador
	var jugadores := get_tree().get_nodes_in_group("jugador")
	if not jugadores.is_empty():
		var cuerpo: CharacterBody3D = jugadores[0]
		var player_nodo: Node = cuerpo.get_parent()
		if player_nodo:
			if datos.has("dinero"):
				player_nodo.set("dinero", int(datos["dinero"]))
			if datos.has("energia"):
				player_nodo.set("energia", float(datos["energia"]))
			if player_nodo.has_method("_refrescar_hud_jugador"):
				player_nodo._refrescar_hud_jugador()
		
		if reaparecer_en_oficina:
			cuerpo.global_position = Vector3(-7.5, 0.05, -19.0)
		elif datos.has("pos_x"):
			cuerpo.global_position = Vector3(float(datos["pos_x"]), float(datos["pos_y"]), float(datos["pos_z"]))
	
	# 2. Restaurar Vidas (corazones)
	var monstruos := get_tree().get_nodes_in_group("gestor_monstruo")
	if not monstruos.is_empty() and datos.has("vidas"):
		var m: Node = monstruos[0]
		var v: int = int(datos["vidas"])
		if v <= 0:
			v = int(m.get("vidas_maximas"))
		m.set("vidas_actuales", v)
		if m.has_method("_actualizar_hud_vidas"):
			m._actualizar_hud_vidas()
	
	# 3. Restaurar Aspiradora
	var aspiradoras := get_tree().get_nodes_in_group("aspiradora")
	if not aspiradoras.is_empty() and datos.has("nivel_aspiradora"):
		var asp: Node = aspiradoras[0]
		var nivel_guardado: int = int(datos["nivel_aspiradora"])
		for n: int in range(1, nivel_guardado + 1):
			asp.set("nivel_mejora", n)
			if asp.has_method("_evolucionar_modelo_voxel"):
				asp._evolucionar_modelo_voxel(n)
		if datos.has("rate_aspirado"):
			asp.set("rate_aspirado", float(datos["rate_aspirado"]))
		if datos.has("radio_aspirado"):
			asp.set("radio_aspirado", float(datos["radio_aspirado"]))
		if datos.has("alcance_aspirado"):
			asp.set("alcance_aspirado", float(datos["alcance_aspirado"]))
	
	# 4. Ocultar Power-Ups ya recogidos
	var raiz := get_tree().current_scene
	if raiz and datos.has("powerups_recogidos"):
		var nodo_pu := raiz.find_child("PowerUps", true, false)
		if nodo_pu and "_items" in nodo_pu:
			var items: Array = nodo_pu.get("_items")
			for idx_raw in datos["powerups_recogidos"]:
				var idx: int = int(idx_raw)
				if idx >= 0 and idx < items.size():
					items[idx]["recogido"] = true
					if is_instance_valid(items[idx]["raiz"]):
						items[idx]["raiz"].visible = false
						items[idx]["raiz"].queue_free()
	
	# 5. Restaurar Filosofía
	var gestores_filo := get_tree().get_nodes_in_group("gestor_filosofia")
	if not gestores_filo.is_empty():
		var gf: Node = gestores_filo[0]
		if datos.has("filo_indice"):
			gf.set("_indice_actual", int(datos["filo_indice"]))
		if datos.has("filo_respuestas"):
			var arr_typed: Array[Dictionary] = []
			for item in datos["filo_respuestas"]:
				if item is Dictionary:
					arr_typed.append(item)
			gf.set("respuestas_jugador", arr_typed)
	
	# 6. Restaurar Suciedad aspirada
	var gestores_suc := get_tree().get_nodes_in_group("gestor_suciedad")
	if not gestores_suc.is_empty() and datos.has("voxels_recogidos"):
		var gs: Node = gestores_suc[0]
		var estados: PackedByteArray = gs.get("_estados")
		var mm: MultiMesh = gs.get("_multimesh")
		var count_recogidos: int = 0
		
		if mm:
			for idx_raw in datos["voxels_recogidos"]:
				var idx: int = int(idx_raw)
				if idx >= 0 and idx < estados.size() and estados[idx] != 2:
					estados[idx] = 2
					mm.set_instance_transform(idx, Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0.0, -50.0, 0.0)))
					count_recogidos += 1
			gs.set("_recogidos", count_recogidos)
			if gs.has_method("_actualizar_hud"):
				gs._actualizar_hud()
	
	_cargando = false

static func borrar_partida() -> void:
	if FileAccess.file_exists(RUTA_SAVE):
		DirAccess.remove_absolute(RUTA_SAVE)
