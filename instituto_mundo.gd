extends Node3D

# Dimensiones generales del instituto (1 planta, 52m de ancho x 34m de fondo)
const ANCHO_TOTAL: float = 52.0   # X de -26.0 a +26.0
const FONDO_TOTAL: float = 34.0   # Z de -46.0 a -12.0
const Z_FRENTE: float = -12.0
const Z_FONDO: float = -46.0
const ALTURA_TECHO: float = 3.6
const GROSOR_EXT: float = 0.45
const GROSOR_INT: float = 0.25

# Coordenadas del pasillo central horizontal
const Z_PASILLO_SUR: float = -26.0
const Z_PASILLO_NORTE: float = -32.0

# Registro público de habitaciones para que luego puedas poblarlas con muebles/tareas
var habitaciones: Array[Dictionary] = []

func _ready() -> void:
	var arq := ConstructorArquitectura.new(self)
	_construir_suelos_y_techos(arq)
	_construir_perimetro_exterior(arq)
	_construir_distribucion_interior(arq)
	_construir_porche_entrada(arq)
	arq.compilar_mallas()
	_crear_iluminacion_interior()

func _construir_suelos_y_techos(arq: ConstructorArquitectura) -> void:
	var z_centro: float = (Z_FRENTE + Z_FONDO) * 0.5
	# Suelo interior ligeramente elevado sobre la peana
	arq.anadir_caja(Vector3(0.0, 0.02, z_centro), Vector3(ANCHO_TOTAL, 0.04, FONDO_TOTAL), "suelo_pasillo", true)
	
	# Techo completo del edificio
	arq.anadir_caja(Vector3(0.0, ALTURA_TECHO + 0.15, z_centro), Vector3(ANCHO_TOTAL + 0.8, 0.3, FONDO_TOTAL + 0.8), "techo", true)
	
	# Luminarias visuales en el techo de los pasillos y el vestíbulo
	for x: float in range(-22, 23, 6):
		arq.anadir_caja(Vector3(x, ALTURA_TECHO - 0.03, -29.0), Vector3(1.6, 0.06, 0.5), "luz_techo", false)
	for z: float in [-16.0, -21.0, -37.0, -42.0]:
		arq.anadir_caja(Vector3(0.0, ALTURA_TECHO - 0.03, z), Vector3(1.6, 0.06, 0.5), "luz_techo", false)

func _construir_perimetro_exterior(arq: ConstructorArquitectura) -> void:
	# Fachada Sur (Z = -12): entrada principal doble abierta en el centro (X = 0, ancho 3.2m) + ventanas
	var aberturas_sur: Array = [
		{"dist": 26.0, "ancho": 3.2, "tipo": "puerta"}
	]
	for x_win: float in [-21.0, -14.0, -7.0, 7.0, 14.0, 21.0]:
		aberturas_sur.append({"dist": x_win + 26.0, "ancho": 2.4, "tipo": "ventana"})
	arq.construir_muro_con_huecos(Vector2(-26.0, Z_FRENTE), Vector2(26.0, Z_FRENTE), ALTURA_TECHO, GROSOR_EXT, "pared_ext", aberturas_sur)
	
	# Fachada Norte (Z = -46): ventanas a lo largo de todas las aulas norte
	var aberturas_norte: Array = []
	for x_win: float in [-21.0, -14.0, -7.0, 0.0, 7.0, 14.0, 21.0]:
		aberturas_norte.append({"dist": x_win + 26.0, "ancho": 2.4, "tipo": "ventana"})
	arq.construir_muro_con_huecos(Vector2(-26.0, Z_FONDO), Vector2(26.0, Z_FONDO), ALTURA_TECHO, GROSOR_EXT, "pared_ext", aberturas_norte)
	
	# Fachada Oeste (X = -26) y Este (X = +26) con ventanas laterales
	var aberturas_lat: Array = [
		{"dist": 5.0, "ancho": 2.2, "tipo": "ventana"},
		{"dist": 17.0, "ancho": 2.0, "tipo": "ventana"},
		{"dist": 29.0, "ancho": 2.2, "tipo": "ventana"}
	]
	arq.construir_muro_con_huecos(Vector2(-26.0, Z_FRENTE), Vector2(-26.0, Z_FONDO), ALTURA_TECHO, GROSOR_EXT, "pared_ext", aberturas_lat)
	arq.construir_muro_con_huecos(Vector2(26.0, Z_FRENTE), Vector2(26.0, Z_FONDO), ALTURA_TECHO, GROSOR_EXT, "pared_ext", aberturas_lat)

func _construir_distribucion_interior(arq: ConstructorArquitectura) -> void:
	# --- ZONA SUR (Z de -12 a -26, profundidad 14m) ---
	# Muro oeste del vestíbulo (X = -4) con puerta a Janitor Office
	arq.construir_muro_con_huecos(Vector2(-4.0, -12.0), Vector2(-4.0, -26.0), ALTURA_TECHO, GROSOR_INT, "pared_int", [
		{"dist": 4.5, "ancho": 1.4, "tipo": "puerta"}
	])
	# Muro este del vestíbulo (X = +4) con puerta a Principal's Office
	arq.construir_muro_con_huecos(Vector2(4.0, -12.0), Vector2(4.0, -26.0), ALTURA_TECHO, GROSOR_INT, "pared_int", [
		{"dist": 4.5, "ancho": 1.4, "tipo": "puerta"}
	])
	
	# Tabiques divisores de las alas Sur
	for x_div: float in [-18.0, -11.0, 11.0, 18.0]:
		arq.construir_muro_con_huecos(Vector2(x_div, -12.0), Vector2(x_div, -26.0), ALTURA_TECHO, GROSOR_INT, "pared_int", [])
	
	# Muro del pasillo Sur (Z = -26)
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
	
	# --- ZONA NORTE (Z de -32 a -46, profundidad 14m) ---
	var cortes_norte: Array[float] = [-18.0, -11.0, -4.0, 4.0, 11.0, 18.0]
	for x_div: float in cortes_norte:
		arq.construir_muro_con_huecos(Vector2(x_div, Z_PASILLO_NORTE), Vector2(x_div, Z_FONDO), ALTURA_TECHO, GROSOR_INT, "pared_int", [])
	
	var puertas_norte: Array = []
	var centros_norte: Array[float] = [-22.0, -14.5, -7.5, 0.0, 7.5, 14.5, 22.0]
	for cx: float in centros_norte:
		puertas_norte.append({"dist": cx + 26.0, "ancho": 1.5, "tipo": "puerta"})
	arq.construir_muro_con_huecos(Vector2(-26.0, Z_PASILLO_NORTE), Vector2(26.0, Z_PASILLO_NORTE), ALTURA_TECHO, GROSOR_INT, "pared_int", puertas_norte)
	
	_registrar_habitaciones()

func _registrar_habitaciones() -> void:
	habitaciones = [
		{"id": "conserjeria", "centro": Vector3(-7.5, 0.0, -19.0), "tamano": Vector3(7.0, ALTURA_TECHO, 14.0)},
		{"id": "aula_sur_1", "centro": Vector3(-14.5, 0.0, -19.0), "tamano": Vector3(7.0, ALTURA_TECHO, 14.0)},
		{"id": "aula_sur_2", "centro": Vector3(-22.0, 0.0, -19.0), "tamano": Vector3(8.0, ALTURA_TECHO, 14.0)},
		{"id": "secretaria", "centro": Vector3(7.5, 0.0, -19.0), "tamano": Vector3(7.0, ALTURA_TECHO, 14.0)},
		{"id": "aula_sur_3", "centro": Vector3(14.5, 0.0, -19.0), "tamano": Vector3(7.0, ALTURA_TECHO, 14.0)},
		{"id": "almacen_sur", "centro": Vector3(22.0, 0.0, -19.0), "tamano": Vector3(8.0, ALTURA_TECHO, 14.0)},
		{"id": "aula_norte_1", "centro": Vector3(-22.0, 0.0, -39.0), "tamano": Vector3(8.0, ALTURA_TECHO, 14.0)},
		{"id": "aula_norte_2", "centro": Vector3(-14.5, 0.0, -39.0), "tamano": Vector3(7.0, ALTURA_TECHO, 14.0)},
		{"id": "aula_norte_3", "centro": Vector3(-7.5, 0.0, -39.0), "tamano": Vector3(7.0, ALTURA_TECHO, 14.0)},
		{"id": "salon_central", "centro": Vector3(0.0, 0.0, -39.0), "tamano": Vector3(8.0, ALTURA_TECHO, 14.0)},
		{"id": "aula_norte_4", "centro": Vector3(7.5, 0.0, -39.0), "tamano": Vector3(7.0, ALTURA_TECHO, 14.0)},
		{"id": "banos", "centro": Vector3(14.5, 0.0, -39.0), "tamano": Vector3(7.0, ALTURA_TECHO, 14.0)},
		{"id": "gimnasio_pequeno", "centro": Vector3(22.0, 0.0, -39.0), "tamano": Vector3(8.0, ALTURA_TECHO, 14.0)}
	]

func _construir_porche_entrada(arq: ConstructorArquitectura) -> void:
	arq.anadir_caja(Vector3(0.0, ALTURA_TECHO + 0.1, Z_FRENTE + 1.4), Vector3(6.5, 0.35, 2.8), "pared_ext", true)
	arq.anadir_caja(Vector3(-2.6, ALTURA_TECHO * 0.5, Z_FRENTE + 2.3), Vector3(0.4, ALTURA_TECHO, 0.4), "zocalo", true)
	arq.anadir_caja(Vector3(2.6, ALTURA_TECHO * 0.5, Z_FRENTE + 2.3), Vector3(0.4, ALTURA_TECHO, 0.4), "zocalo", true)

func _crear_iluminacion_interior() -> void:
	# Luz ambiental base para que las sombras nunca sean negro puro
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.14, 0.14, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.58)
	env.ambient_light_energy = 0.85
	env_node.environment = env
	add_child(env_node)
	
	# Focos de luz en vestíbulo, pasillo principal y Janitor Office
	var puntos_luz: Array[Vector3] = [
		Vector3(0.0, 3.1, -18.0),   # Vestíbulo
		Vector3(0.0, 3.1, -29.0),   # Cruce central
		Vector3(-12.0, 3.1, -29.0), # Pasillo Oeste 1
		Vector3(-22.0, 3.1, -29.0), # Pasillo Oeste 2
		Vector3(12.0, 3.1, -29.0),  # Pasillo Este 1
		Vector3(22.0, 3.1, -29.0),  # Pasillo Este 2
		Vector3(-7.5, 3.1, -19.0)   # Janitor Office
	]
	
	for pos: Vector3 in puntos_luz:
		var omni := OmniLight3D.new()
		omni.position = pos
		omni.omni_range = 15.0
		omni.omni_attenuation = 1.1
		omni.light_energy = 1.7 if pos.x == -7.5 else 1.3
		omni.shadow_enabled = false
		add_child(omni)
