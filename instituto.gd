extends Node3D

const VOXEL_SIZE: float = 0.35
const GAP: float = 0.94 # Ligera separación (6%) para que se marque cada vóxel individual

var _rng := RandomNumberGenerator.new()

# Diccionario de grupos: clave -> Array de Transform3D
var _grupos: Dictionary = {
	"pared_1": [],
	"pared_2": [],
	"pared_3": [],
	"pared_4": [],
	"techo_1": [],
	"techo_2": [],
	"detalle_1": [],
	"detalle_2": [],
	"ventana_apagada": [],
	"ventana_encendida": [],
	"puerta": []
}

func _ready() -> void:
	position = Vector3(0.0, 0.0, -28.0)
	_rng.seed = 42069
	_construir_modelo_voxel()
	_compilar_multimeshes()

func _add_voxel(gx: int, gy: int, gz: int, grupo: String) -> void:
	var pos := Vector3(float(gx) * VOXEL_SIZE, (float(gy) + 0.5) * VOXEL_SIZE, float(gz) * VOXEL_SIZE)
	var t := Transform3D(Basis(), pos)
	_grupos[grupo].append(t)

func _add_box_voxels(x0: int, x1: int, y0: int, y1: int, z0: int, z1: int, tipo: String, hueco: bool = true) -> void:
	for x: int in range(x0, x1 + 1):
		for y: int in range(y0, y1 + 1):
			for z: int in range(z0, z1 + 1):
				# Si es hueco, solo generamos la cáscara exterior para optimizar al máximo
				if hueco and x > x0 and x < x1 and y > y0 and y < y1 and z > z0 and z < z1:
					continue
				var grupo_final: String = _elegir_variacion(tipo, x, y, z)
				_add_voxel(x, y, z, grupo_final)

func _elegir_variacion(tipo: String, x: int, y: int, z: int) -> String:
	# Hash determinista espacial para variar el tono vóxel a vóxel con patrón natural
	var h: int = abs((x * 73856093) ^ (y * 19349663) ^ (z * 83492791))
	match tipo:
		"pared":
			var idx: int = (h % 4) + 1
			return "pared_" + str(idx)
		"techo":
			var idx: int = (h % 2) + 1
			return "techo_" + str(idx)
		"detalle":
			var idx: int = (h % 2) + 1
			return "detalle_" + str(idx)
		_:
			return tipo

func _construir_modelo_voxel() -> void:
	# 1. Bloque central (2 plantas: ancho ~22m -> x de -31 a 31, alto ~9m -> y de 0 a 25, fondo -> z de -16 a 16)
	_add_box_voxels(-31, 31, 0, 25, -16, 16, "pared")
	# Cornisa y tejado bloque central
	_add_box_voxels(-32, 32, 26, 27, -17, 17, "techo")
	
	# 2. Alas izquierda y derecha
	for lado: int in [-1, 1]:
		var cx: int = lado * 47
		_add_box_voxels(cx - 15, cx + 15, 0, 21, -13, 15, "pared")
		_add_box_voxels(cx - 16, cx + 16, 22, 23, -14, 16, "techo")
	
	# 3. Entrada principal: escalones, porche, columnas y puertas dobles
	_add_box_voxels(-10, 10, 0, 0, 17, 23, "detalle")
	_add_box_voxels(-9, 9, 1, 1, 17, 21, "detalle")
	# Marquesina superior del porche
	_add_box_voxels(-11, 11, 11, 12, 17, 23, "techo")
	# Columnas del porche
	for col_x: int in [-9, 9]:
		_add_box_voxels(col_x - 1, col_x, 2, 10, 21, 22, "detalle")
	# Marco y puertas dobles en la fachada (z = 16)
	_add_box_voxels(-5, 5, 2, 9, 16, 16, "detalle", false)
	_add_box_voxels(-4, 4, 2, 8, 16, 16, "puerta", false)
	
	# 4. Torre del reloj central
	_add_box_voxels(-7, 7, 28, 37, -7, 7, "pared")
	_add_box_voxels(-8, 8, 38, 39, -8, 8, "techo")
	# Esfera de vóxeles del reloj en z = 7
	for rx: int in range(-3, 4):
		for ry: int in range(30, 36):
			var dx: float = float(rx)
			var dy: float = float(ry) - 32.5
			if (dx * dx + dy * dy) <= 9.5:
				_add_voxel(rx, ry, 7, "ventana_encendida")
	# Manecillas oscuras en el centro del reloj
	_add_voxel(0, 33, 7, "puerta")
	_add_voxel(0, 34, 7, "puerta")
	_add_voxel(1, 33, 7, "puerta")
	
	# 5. Ventanas del bloque central (sustituyendo vóxeles en z = 16)
	for piso: int in range(2):
		var y_base: int = 5 + piso * 11
		for col: int in range(-3, 4):
			if piso == 0 and abs(col) <= 1:
				continue
			var x_centro: int = col * 8
			var encendida: bool = (piso == 1 and col == 2) or (piso == 0 and col == -3)
			var tipo_v: String = "ventana_encendida" if encendida else "ventana_apagada"
			# Marco de ventana y cristal
			_add_box_voxels(x_centro - 2, x_centro + 2, y_base - 1, y_base + 5, 16, 16, "detalle", false)
			_add_box_voxels(x_centro - 1, x_centro + 1, y_base, y_base + 4, 16, 16, tipo_v, false)
			
	# 6. Ventanas de las alas laterales (en z = 15)
	for lado: int in [-1, 1]:
		var cx: int = lado * 47
		for piso: int in range(2):
			var y_base: int = 4 + piso * 9
			for col: int in range(-1, 2):
				var x_centro: int = cx + col * 9
				var encendida: bool = (lado == -1 and piso == 1 and col == 0)
				var tipo_v: String = "ventana_encendida" if encendida else "ventana_apagada"
				_add_box_voxels(x_centro - 2, x_centro + 2, y_base - 1, y_base + 4, 15, 15, "detalle", false)
				_add_box_voxels(x_centro - 1, x_centro + 1, y_base, y_base + 3, 15, 15, tipo_v, false)

func _crear_material_voxel(tono: float, emission_energy: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var c := Color(tono, tono, tono)
	mat.albedo_color = c
	mat.roughness = 0.88
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = c
		mat.emission_energy_multiplier = emission_energy
	return mat

func _compilar_multimeshes() -> void:
	# Definimos los tonos ligeramente escalonados para que cada vóxel destaque
	var paleta: Dictionary = {
		"pared_1": _crear_material_voxel(0.40),
		"pared_2": _crear_material_voxel(0.46),
		"pared_3": _crear_material_voxel(0.52),
		"pared_4": _crear_material_voxel(0.36),
		"techo_1": _crear_material_voxel(0.15),
		"techo_2": _crear_material_voxel(0.21),
		"detalle_1": _crear_material_voxel(0.24),
		"detalle_2": _crear_material_voxel(0.30),
		"ventana_apagada": _crear_material_voxel(0.06),
		"ventana_encendida": _crear_material_voxel(0.92, 0.8),
		"puerta": _crear_material_voxel(0.11)
	}
	
	# Rejilla única con tamaño ligeramente inferior al paso (GAP) para marcar las juntas entre vóxeles
	var malla_cubo := BoxMesh.new()
	var lado_visual: float = VOXEL_SIZE * GAP
	malla_cubo.size = Vector3(lado_visual, lado_visual, lado_visual)
	
	for clave: String in _grupos.keys():
		var lista: Array = _grupos[clave]
		if lista.is_empty():
			continue
		
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = malla_cubo
		mm.instance_count = lista.size()
		
		for i: int in range(lista.size()):
			mm.set_instance_transform(i, lista[i])
		
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Voxels_" + clave
		mmi.multimesh = mm
		mmi.material_override = paleta[clave]
		add_child(mmi)
