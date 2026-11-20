class_name ConstructorArquitectura
extends RefCounted

const VOXEL_SIZE: float = 0.40
const GAP: float = 0.96 # Ligera junta del 4% para que se distinga cada vóxel pequeño

var _padre: Node3D
var _cuerpo_colision: StaticBody3D
var _materiales: Dictionary = {}

# Mapa espacial de vóxeles: Vector3i -> String (clave de material con variación de tono)
var _voxels: Dictionary = {}

# Registro 2D de celdas ocupadas a altura de paso (gy entre 0 y 5 -> 0.0m a 2.4m)
var celdas_bloqueadas: Dictionary = {} # Vector2i -> true

func _init(padre: Node3D) -> void:
	_padre = padre
	_cuerpo_colision = StaticBody3D.new()
	_cuerpo_colision.name = "ColisionesInstituto"
	_padre.add_child(_cuerpo_colision)
	_crear_paleta_variada()

func _crear_paleta_variada() -> void:
	_registrar_mat("pared_ext_1", Color(0.46, 0.41, 0.38), 0.92)
	_registrar_mat("pared_ext_2", Color(0.41, 0.36, 0.33), 0.92)
	_registrar_mat("pared_ext_3", Color(0.51, 0.45, 0.41), 0.92)
	_registrar_mat("pared_ext_4", Color(0.37, 0.33, 0.31), 0.92)
	
	_registrar_mat("pared_int_1", Color(0.74, 0.73, 0.67), 0.88)
	_registrar_mat("pared_int_2", Color(0.69, 0.68, 0.62), 0.88)
	_registrar_mat("pared_int_3", Color(0.78, 0.76, 0.70), 0.88)
	_registrar_mat("pared_int_4", Color(0.65, 0.64, 0.59), 0.88)
	
	_registrar_mat("zocalo_1", Color(0.24, 0.31, 0.30), 0.78)
	_registrar_mat("zocalo_2", Color(0.20, 0.27, 0.26), 0.78)
	_registrar_mat("zocalo_3", Color(0.28, 0.35, 0.34), 0.78)
	
	_registrar_mat("marco_1", Color(0.26, 0.19, 0.14), 0.75)
	_registrar_mat("marco_2", Color(0.21, 0.15, 0.11), 0.75)
	
	_registrar_mat("suelo_pasillo_1", Color(0.56, 0.55, 0.52), 0.65)
	_registrar_mat("suelo_pasillo_2", Color(0.48, 0.47, 0.45), 0.65)
	_registrar_mat("suelo_pasillo_3", Color(0.61, 0.60, 0.57), 0.65)
	_registrar_mat("suelo_pasillo_4", Color(0.43, 0.42, 0.40), 0.65)
	
	_registrar_mat("techo_1", Color(0.82, 0.82, 0.79), 0.92)
	_registrar_mat("techo_2", Color(0.76, 0.76, 0.73), 0.92)
	
	_registrar_mat("cristal_1", Color(0.60, 0.74, 0.80, 0.32), 0.15, true)
	_registrar_mat("luz_techo_1", Color(0.96, 0.96, 0.90), 0.3, false, 0.95)

func _registrar_mat(nombre: String, color: Color, roughness: float, transparente: bool = false, emision: float = 0.0) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	if transparente:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emision > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emision
	_materiales[nombre] = mat

func _elegir_variacion(mat_base: String, gx: int, gy: int, gz: int) -> String:
	var tipo: String = mat_base
	if mat_base == "pared_int" and gy >= 0 and gy <= 2:
		tipo = "zocalo"
	
	var h: int = abs((gx * 73856093) ^ (gy * 19349663) ^ (gz * 83492791))
	match tipo:
		"pared_ext":
			return "pared_ext_" + str((h % 4) + 1)
		"pared_int":
			return "pared_int_" + str((h % 4) + 1)
		"zocalo":
			return "zocalo_" + str((h % 3) + 1)
		"marco":
			return "marco_" + str((h % 2) + 1)
		"suelo_pasillo", "suelo_aula":
			var damero: int = abs(gx + gz) % 2
			var var_extra: int = (h % 2)
			return "suelo_pasillo_" + str(damero * 2 + var_extra + 1)
		"techo":
			return "techo_" + str((h % 2) + 1)
		"cristal":
			return "cristal_1"
		"luz_techo":
			return "luz_techo_1"
		_:
			return "pared_int_1"

func anadir_caja(centro: Vector3, tamano: Vector3, mat_key: String, con_colision: bool = true) -> void:
	var min_p: Vector3 = centro - tamano * 0.5
	var max_p: Vector3 = centro + tamano * 0.5
	
	var x0: int = int(floor((min_p.x + 0.001) / VOXEL_SIZE))
	var x1: int = int(ceil((max_p.x - 0.001) / VOXEL_SIZE)) - 1
	var y0: int = int(floor((min_p.y + 0.001) / VOXEL_SIZE))
	var y1: int = int(ceil((max_p.y - 0.001) / VOXEL_SIZE)) - 1
	var z0: int = int(floor((min_p.z + 0.001) / VOXEL_SIZE))
	var z1: int = int(ceil((max_p.z - 0.001) / VOXEL_SIZE)) - 1
	
	if x1 < x0: x1 = x0
	if y1 < y0: y1 = y0
	if z1 < z0: z1 = z0
	
	for gx: int in range(x0, x1 + 1):
		for gy: int in range(y0, y1 + 1):
			for gz: int in range(z0, z1 + 1):
				var coord := Vector3i(gx, gy, gz)
				if not _voxels.has(coord) or mat_key == "marco":
					_voxels[coord] = _elegir_variacion(mat_key, gx, gy, gz)
				
				# Si tiene colisión y está a altura transitable (gy 0..5 -> 0.0m a 2.4m), bloqueamos la celda XZ
				if con_colision and gy >= 0 and gy <= 5:
					celdas_bloqueadas[Vector2i(gx, gz)] = true
	
	if con_colision:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = tamano
		col.shape = shape
		col.position = centro
		_cuerpo_colision.add_child(col)

func construir_muro_con_huecos(p1: Vector2, p2: Vector2, altura: float, grosor: float, mat_key: String, aberturas: Array = []) -> void:
	var dir_2d: Vector2 = p2 - p1
	var largo_total: float = dir_2d.length()
	if largo_total < 0.05:
		return
	var dir_u: Vector2 = dir_2d / largo_total
	var es_horizontal: bool = abs(dir_u.x) > abs(dir_u.y)
	
	var lista: Array = aberturas.duplicate()
	lista.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["dist"] < b["dist"])
	
	var cursor: float = 0.0
	for ab: Dictionary in lista:
		var dist_centro: float = ab["dist"]
		var ancho: float = ab["ancho"]
		var tipo: String = ab.get("tipo", "puerta")
		var inicio_hueco: float = max(0.0, dist_centro - ancho * 0.5)
		var fin_hueco: float = min(largo_total, dist_centro + ancho * 0.5)
		
		if inicio_hueco > cursor + 0.02:
			_tramo_muro(p1, dir_u, cursor, inicio_hueco, 0.0, altura, grosor, mat_key, es_horizontal)
		
		var centro_h: Vector2 = p1 + dir_u * ((inicio_hueco + fin_hueco) * 0.5)
		var ancho_real: float = fin_hueco - inicio_hueco
		if tipo == "puerta":
			var alto_puerta: float = 2.4
			_tramo_muro(p1, dir_u, inicio_hueco, fin_hueco, alto_puerta, altura, grosor, mat_key, es_horizontal)
			_colocar_pieza_alineada(centro_h - dir_u * (ancho_real * 0.5 - 0.1), alto_puerta * 0.5, Vector3(0.2, alto_puerta, grosor + 0.08), "marco", es_horizontal, false)
			_colocar_pieza_alineada(centro_h + dir_u * (ancho_real * 0.5 - 0.1), alto_puerta * 0.5, Vector3(0.2, alto_puerta, grosor + 0.08), "marco", es_horizontal, false)
			_colocar_pieza_alineada(centro_h, alto_puerta - 0.1, Vector3(ancho_real, 0.2, grosor + 0.08), "marco", es_horizontal, false)
		elif tipo == "ventana":
			var y_inf: float = 1.2
			var y_sup: float = 2.4
			_tramo_muro(p1, dir_u, inicio_hueco, fin_hueco, 0.0, y_inf, grosor, mat_key, es_horizontal)
			_tramo_muro(p1, dir_u, inicio_hueco, fin_hueco, y_sup, altura, grosor, mat_key, es_horizontal)
			_colocar_pieza_alineada(centro_h, (y_inf + y_sup) * 0.5, Vector3(ancho_real, y_sup - y_inf, 0.2), "cristal", es_horizontal, true)
			_colocar_pieza_alineada(centro_h, y_inf + 0.1, Vector3(ancho_real, 0.2, grosor + 0.08), "marco", es_horizontal, false)
			
		cursor = fin_hueco
	
	if largo_total > cursor + 0.02:
		_tramo_muro(p1, dir_u, cursor, largo_total, 0.0, altura, grosor, mat_key, es_horizontal)

func _tramo_muro(p1: Vector2, dir_u: Vector2, d0: float, d1: float, y0: float, y1: float, grosor: float, mat_key: String, es_horizontal: bool) -> void:
	var largo: float = d1 - d0
	var alto: float = y1 - y0
	if largo <= 0.01 or alto <= 0.01:
		return
	var centro_2d: Vector2 = p1 + dir_u * ((d0 + d1) * 0.5)
	_colocar_pieza_alineada(centro_2d, (y0 + y1) * 0.5, Vector3(largo, alto, grosor), mat_key, es_horizontal, true)

func _colocar_pieza_alineada(pos_2d: Vector2, y_centro: float, tam_local: Vector3, mat_key: String, es_horizontal: bool, con_colision: bool) -> void:
	var tam: Vector3 = tam_local if es_horizontal else Vector3(tam_local.z, tam_local.y, tam_local.x)
	anadir_caja(Vector3(pos_2d.x, y_centro, pos_2d.y), tam, mat_key, con_colision)

func compilar_mallas() -> void:
	var grupos: Dictionary = {}
	var vecinos: Array[Vector3i] = [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1)
	]
	
	for coord: Vector3i in _voxels.keys():
		var mat_key: String = _voxels[coord]
		if mat_key != "cristal_1":
			var oculto: bool = true
			for dir: Vector3i in vecinos:
				var c_vec: Vector3i = coord + dir
				if not _voxels.has(c_vec) or _voxels[c_vec] == "cristal_1":
					oculto = false
					break
			if oculto:
				continue
		
		if not grupos.has(mat_key):
			grupos[mat_key] = []
		
		# Sin offset artificial en Y: gy = -1 queda en [-0.40, 0.00] (suelo a ras de Y = 0.0)
		# y gy = 0 queda en [0.00, +0.40] apoyado encima del suelo.
		var pos := Vector3(
			(float(coord.x) + 0.5) * VOXEL_SIZE,
			(float(coord.y) + 0.5) * VOXEL_SIZE,
			(float(coord.z) + 0.5) * VOXEL_SIZE
		)
		grupos[mat_key].append(Transform3D(Basis(), pos))
	
	var malla_cubo := BoxMesh.new()
	var lado: float = VOXEL_SIZE * GAP
	malla_cubo.size = Vector3(lado, lado, lado)
	
	for mat_key: String in grupos.keys():
		var lista: Array = grupos[mat_key]
		if lista.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = malla_cubo
		mm.instance_count = lista.size()
		for i: int in range(lista.size()):
			mm.set_instance_transform(i, lista[i])
		
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Voxels_" + mat_key
		mmi.multimesh = mm
		mmi.material_override = _materiales[mat_key]
		_padre.add_child(mmi)
	
	_voxels.clear()
