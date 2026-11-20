extends Node3D

const ANCHO_TOTAL: float = 52.0   # X de -26.0 a +26.0
const FONDO_TOTAL: float = 34.0   # Z de -46.0 a -12.0
const Z_FRENTE: float = -12.0
const Z_FONDO: float = -46.0
const ALTURA_TECHO: float = 3.6
const GROSOR_EXT: float = 0.45
const GROSOR_INT: float = 0.25

const Z_PASILLO_SUR: float = -26.0
const Z_PASILLO_NORTE: float = -32.0
const GRID_STEP: float = ConstructorArquitectura.VOXEL_SIZE # 0.40m

# Datos públicos centralizados
var pasillos: Array[Dictionary] = []
var habitaciones: Array[Dictionary] = []
var _celdas_ocupadas: Dictionary = {} # Vector2i -> true

func _enter_tree() -> void:
	add_to_group("mapa_instituto")

func _ready() -> void:
	var arq := ConstructorArquitectura.new(self)
	_construir_suelos_y_techos(arq)
	_construir_perimetro_exterior(arq)
	_construir_distribucion_interior(arq)
	_construir_porche_entrada(arq)
	
	# Importamos todas las celdas bloqueadas por muros y marcos
	_celdas_ocupadas = arq.celdas_bloqueadas.duplicate()
	
	arq.compilar_mallas()
	_crear_iluminacion_interior()

func _construir_suelos_y_techos(arq: ConstructorArquitectura) -> void:
	var z_centro: float = (Z_FRENTE + Z_FONDO) * 0.5
	# Suelo de vóxeles de -0.40 a 0.00: superficie exacta en Y = 0.00
	arq.anadir_caja(Vector3(0.0, -0.20, z_centro), Vector3(ANCHO_TOTAL, 0.40, FONDO_TOTAL), "suelo_pasillo", true)
	
	# Techo completo del edificio (de Y = 3.60 a 4.00)
	arq.anadir_caja(Vector3(0.0, ALTURA_TECHO + 0.20, z_centro), Vector3(ANCHO_TOTAL + 0.8, 0.40, FONDO_TOTAL + 0.8), "techo", true)
	
	# Luminarias visuales en el techo
	for x: float in range(-22, 23, 6):
		arq.anadir_caja(Vector3(x, ALTURA_TECHO - 0.05, -29.0), Vector3(1.6, 0.10, 0.5), "luz_techo", false)
	for z: float in [-16.0, -21.0, -37.0, -42.0]:
		arq.anadir_caja(Vector3(0.0, ALTURA_TECHO - 0.05, z), Vector3(1.6, 0.10, 0.5), "luz_techo", false)

func _construir_perimetro_exterior(arq: ConstructorArquitectura) -> void:
	var aberturas_sur: Array = [{"dist": 26.0, "ancho": 3.2, "tipo": "puerta"}]
	for x_win: float in [-21.0, -14.0, -7.0, 7.0, 14.0, 21.0]:
		aberturas_sur.append({"dist": x_win + 26.0, "ancho": 2.4, "tipo": "ventana"})
	arq.construir_muro_con_huecos(Vector2(-26.0, Z_FRENTE), Vector2(26.0, Z_FRENTE), ALTURA_TECHO, GROSOR_EXT, "pared_ext", aberturas_sur)
	
	var aberturas_norte: Array = []
	for x_win: float in [-21.0, -14.0, -7.0, 0.0, 7.0, 14.0, 21.0]:
		aberturas_norte.append({"dist": x_win + 26.0, "ancho": 2.4, "tipo": "ventana"})
	arq.construir_muro_con_huecos(Vector2(-26.0, Z_FONDO), Vector2(26.0, Z_FONDO), ALTURA_TECHO, GROSOR_EXT, "pared_ext", aberturas_norte)
	
	var aberturas_lat: Array = [
		{"dist": 5.0, "ancho": 2.2, "tipo": "ventana"},
		{"dist": 17.0, "ancho": 2.0, "tipo": "ventana"},
		{"dist": 29.0, "ancho": 2.2, "tipo": "ventana"}
	]
	arq.construir_muro_con_huecos(Vector2(-26.0, Z_FRENTE), Vector2(-26.0, Z_FONDO), ALTURA_TECHO, GROSOR_EXT, "pared_ext", aberturas_lat)
	arq.construir_muro_con_huecos(Vector2(26.0, Z_FRENTE), Vector2(26.0, Z_FONDO), ALTURA_TECHO, GROSOR_EXT, "pared_ext", aberturas_lat)

func _construir_distribucion_interior(arq: ConstructorArquitectura) -> void:
	arq.construir_muro_con_huecos(Vector2(-4.0, -12.0), Vector2(-4.0, -26.0), ALTURA_TECHO, GROSOR_INT, "pared_int", [
		{"dist": 4.5, "ancho": 1.4, "tipo": "puerta"}
	])
	arq.construir_muro_con_huecos(Vector2(4.0, -12.0), Vector2(4.0, -26.0), ALTURA_TECHO, GROSOR_INT, "pared_int", [
		{"dist": 4.5, "ancho": 1.4, "tipo": "puerta"}
	])
	
	for x_div: float in [-18.0, -11.0, 11.0, 18.0]:
		arq.construir_muro_con_huecos(Vector2(x_div, -12.0), Vector2(x_div, -26.0), ALTURA_TECHO, GROSOR_INT, "pared_int", [])
	
	arq.construir_muro_con_huecos(Vector2(-26.0, Z_PASILLO_SUR), Vector2(-4.0, Z_PASILLO_SUR), ALTURA_TECHO, GROSOR_INT, "pared_int", [
		{"dist": 4.0, "ancho": 1.5, "tipo": "puerta"},
		{"dist": 11.5, "ancho": 1.5, "tipo": "puerta"},
		{"dist": 18.5, "ancho": 1.5, "tipo": "puerta"}
	])
	arq.construir_muro_con_huecos(Vector2(4.0, Z_PASILLO_SUR), Vector2(26.0, Z_PASILLO_SUR), ALTURA_TECHO, GROSOR_INT, "pared_int", [
		{"dist": 3.5, "ancho": 1.5, "tipo": "puerta"},
		{"dist": 10.5, "ancho": 1.5, "tipo": "puerta"},
		{"dist": 18.0, "ancho": 1.5, "tipo": "puerta"}
	])
	
	var cortes_norte: Array[float] = [-18.0, -11.0, -4.0, 4.0, 11.0, 18.0]
	for x_div: float in cortes_norte:
		arq.construir_muro_con_huecos(Vector2(x_div, Z_PASILLO_NORTE), Vector2(x_div, Z_FONDO), ALTURA_TECHO, GROSOR_INT, "pared_int", [])
	
	var puertas_norte: Array = []
	var centros_norte: Array[float] = [-22.0, -14.5, -7.5, 0.0, 7.5, 14.5, 22.0]
	for cx: float in centros_norte:
		puertas_norte.append({"dist": cx + 26.0, "ancho": 1.5, "tipo": "puerta"})
	arq.construir_muro_con_huecos(Vector2(-26.0, Z_PASILLO_NORTE), Vector2(26.0, Z_PASILLO_NORTE), ALTURA_TECHO, GROSOR_INT, "pared_int", puertas_norte)
	
	_registrar_espacios()

func _registrar_espacios() -> void:
	pasillos = [
		{"id": "main_hallway", "nombre": "Main Hallway", "centro": Vector3(0.0, 1.8, -29.0), "tamano": Vector3(51.0, 3.4, 5.4), "segura": false},
		{"id": "lobby",        "nombre": "Main Hallway (Lobby)", "centro": Vector3(0.0, 1.8, -19.2), "tamano": Vector3(7.4, 3.4, 14.0), "segura": false}
	]
	
	habitaciones = [
		# Ala Sur
		{"id": "conserjeria",      "nombre": "Janitor Office",     "centro": Vector3(-7.5,  1.8, -19.0), "tamano": Vector3(6.6, 3.4, 13.2), "segura": true},
		{"id": "aula_sur_1",       "nombre": "Classroom 101",      "centro": Vector3(-14.5, 1.8, -19.0), "tamano": Vector3(6.6, 3.4, 13.2), "segura": false},
		{"id": "aula_sur_2",       "nombre": "Classroom 102",      "centro": Vector3(-22.0, 1.8, -19.0), "tamano": Vector3(7.4, 3.4, 13.2), "segura": false},
		{"id": "secretaria",       "nombre": "Principal's Office", "centro": Vector3(7.5,   1.8, -19.0), "tamano": Vector3(6.6, 3.4, 13.2), "segura": false},
		{"id": "aula_sur_3",       "nombre": "Classroom 103",      "centro": Vector3(14.5,  1.8, -19.0), "tamano": Vector3(6.6, 3.4, 13.2), "segura": false},
		{"id": "almacen_sur",      "nombre": "Storage Room",       "centro": Vector3(22.0,  1.8, -19.0), "tamano": Vector3(7.4, 3.4, 13.2), "segura": false},
		# Ala Norte
		{"id": "aula_norte_1",     "nombre": "Science Lab",        "centro": Vector3(-22.0, 1.8, -39.0), "tamano": Vector3(7.4, 3.4, 13.2), "segura": false},
		{"id": "aula_norte_2",     "nombre": "Classroom 201",      "centro": Vector3(-14.5, 1.8, -39.0), "tamano": Vector3(6.6, 3.4, 13.2), "segura": false},
		{"id": "aula_norte_3",     "nombre": "Classroom 202",      "centro": Vector3(-7.5,  1.8, -39.0), "tamano": Vector3(6.6, 3.4, 13.2), "segura": false},
		{"id": "salon_central",    "nombre": "Library",            "centro": Vector3(0.0,   1.8, -39.0), "tamano": Vector3(7.5, 3.4, 13.2), "segura": false},
		{"id": "aula_norte_4",     "nombre": "Art Room",           "centro": Vector3(7.5,   1.8, -39.0), "tamano": Vector3(6.6, 3.4, 13.2), "segura": false},
		{"id": "banos",            "nombre": "Restrooms",          "centro": Vector3(14.5,  1.8, -39.0), "tamano": Vector3(6.6, 3.4, 13.2), "segura": false},
		{"id": "gimnasio_pequeno", "nombre": "Gymnasium",          "centro": Vector3(22.0,  1.8, -39.0), "tamano": Vector3(7.4, 3.4, 13.2), "segura": false}
	]

# --- API PÚBLICA PARA MOBILIARIO, SUCIEDAD Y MONSTRUO ---

func registrar_obstaculo(centro: Vector3, tamano: Vector3, margen: float = 0.08) -> void:
	var min_p: Vector3 = centro - (tamano * 0.5) - Vector3(margen, 0.0, margen)
	var max_p: Vector3 = centro + (tamano * 0.5) + Vector3(margen, 0.0, margen)
	var x0: int = int(floor(min_p.x / GRID_STEP))
	var x1: int = int(floor(max_p.x / GRID_STEP))
	var z0: int = int(floor(min_p.z / GRID_STEP))
	var z1: int = int(floor(max_p.z / GRID_STEP))
	for gx: int in range(x0, x1 + 1):
		for gz: int in range(z0, z1 + 1):
			_celdas_ocupadas[Vector2i(gx, gz)] = true

func esta_bloqueado(x: float, z: float) -> bool:
	if x < -25.4 or x > 25.4 or z < -45.4 or z > -12.6:
		return true
	var gx: int = int(floor(x / GRID_STEP))
	var gz: int = int(floor(z / GRID_STEP))
	return _celdas_ocupadas.has(Vector2i(gx, gz))

func es_zona_segura(pos: Vector3) -> bool:
	for hab: Dictionary in habitaciones:
		if not hab["segura"]:
			continue
		var c: Vector3 = hab["centro"]
		var half: Vector3 = hab["tamano"] * 0.5
		if abs(pos.x - c.x) <= half.x and abs(pos.z - c.z) <= half.z:
			return true
	return false

func _construir_porche_entrada(arq: ConstructorArquitectura) -> void:
	arq.anadir_caja(Vector3(0.0, ALTURA_TECHO + 0.1, Z_FRENTE + 1.4), Vector3(6.5, 0.35, 2.8), "pared_ext", true)
	arq.anadir_caja(Vector3(-2.6, ALTURA_TECHO * 0.5, Z_FRENTE + 2.3), Vector3(0.4, ALTURA_TECHO, 0.4), "zocalo", true)
	arq.anadir_caja(Vector3(2.6, ALTURA_TECHO * 0.5, Z_FRENTE + 2.3), Vector3(0.4, ALTURA_TECHO, 0.4), "zocalo", true)

func _crear_iluminacion_interior() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.14, 0.14, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.58)
	env.ambient_light_energy = 0.85
	env_node.environment = env
	add_child(env_node)
	
	var puntos_luz: Array[Vector3] = [
		Vector3(0.0, 3.1, -18.0),
		Vector3(0.0, 3.1, -29.0),
		Vector3(-12.0, 3.1, -29.0),
		Vector3(-22.0, 3.1, -29.0),
		Vector3(12.0, 3.1, -29.0),
		Vector3(22.0, 3.1, -29.0),
		Vector3(-7.5, 3.1, -19.0)
	]
	
	for pos: Vector3 in puntos_luz:
		var omni := OmniLight3D.new()
		omni.position = pos
		omni.omni_range = 15.0
		omni.omni_attenuation = 1.1
		omni.light_energy = 1.7 if pos.x == -7.5 else 1.3
		omni.shadow_enabled = false
		add_child(omni)
