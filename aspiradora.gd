extends Node3D

@export var rate_aspirado: float = 6.0      # Vóxeles por segundo (subirá con Power-Ups)
@export var radio_aspirado: float = 0.65    # Radio de succión en el suelo (metros)
@export var alcance_aspirado: float = 2.35  # Distancia máxima hasta el suelo

var nivel_mejora: int = 0

var _player: Node
var _pivot: Node3D
var _boquilla: Node3D
var _cabezal_base: MeshInstance3D
var _led_mat: StandardMaterial3D
var _mat_cable: StandardMaterial3D
var _mat_modulo: StandardMaterial3D
var _mat_nucleo_glow: StandardMaterial3D

var _encendida: bool = false
var _acumulador_succion: float = 0.0
var _tiempo_vibracion: float = 0.0
var _pos_base := Vector3(0.28, -0.20, -0.38)

func _ready() -> void:
	add_to_group("aspiradora")
	_player = get_parent()
	call_deferred("_montar_en_camara")

func _montar_en_camara() -> void:
	if not _player or not ("camara" in _player) or not _player.camara:
		return
	
	if _player.has_signal("estado_aspiradora_cambiado"):
		_player.estado_aspiradora_cambiado.connect(func(activa: bool) -> void: _encendida = activa)
	
	_pivot = Node3D.new()
	_pivot.name = "ModeloAspiradora"
	_pivot.position = _pos_base
	_player.camara.add_child(_pivot)
	
	var mat_metal := StandardMaterial3D.new()
	mat_metal.albedo_color = Color(0.55, 0.56, 0.58)
	mat_metal.metallic = 0.6
	mat_metal.roughness = 0.35
	
	var mat_plastico := StandardMaterial3D.new()
	mat_plastico.albedo_color = Color(0.16, 0.16, 0.18)
	mat_plastico.roughness = 0.75
	
	_mat_cable = StandardMaterial3D.new()
	_mat_cable.albedo_color = Color(0.82, 0.32, 0.22)
	_mat_cable.roughness = 0.6
	
	_mat_modulo = StandardMaterial3D.new()
	_mat_modulo.albedo_color = Color(0.32, 0.36, 0.42)
	_mat_modulo.metallic = 0.45
	_mat_modulo.roughness = 0.4
	
	_mat_nucleo_glow = StandardMaterial3D.new()
	_mat_nucleo_glow.albedo_color = Color(0.45, 0.90, 0.98)
	_mat_nucleo_glow.emission_enabled = true
	_mat_nucleo_glow.emission = Color(0.45, 0.90, 0.98)
	_mat_nucleo_glow.emission_energy_multiplier = 1.6
	
	_led_mat = StandardMaterial3D.new()
	_led_mat.albedo_color = Color(0.2, 0.2, 0.2)
	_led_mat.emission_enabled = true
	_led_mat.emission = Color(0.95, 0.95, 0.95)
	_led_mat.emission_energy_multiplier = 0.0
	
	# Empuñadura
	var mango := MeshInstance3D.new()
	var box_mango := BoxMesh.new()
	box_mango.size = Vector3(0.055, 0.085, 0.16)
	mango.mesh = box_mango
	mango.material_override = mat_plastico
	mango.rotation_degrees.x = -18.0
	_pivot.add_child(mango)
	
	# Piloto LED
	var led := MeshInstance3D.new()
	var box_led := BoxMesh.new()
	box_led.size = Vector3(0.03, 0.015, 0.03)
	led.mesh = box_led
	led.material_override = _led_mat
	led.position = Vector3(0.0, 0.048, -0.03)
	_pivot.add_child(led)
	
	# Tubo compacto
	var tubo := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.02
	cyl.bottom_radius = 0.02
	cyl.height = 0.56
	tubo.mesh = cyl
	tubo.material_override = mat_metal
	tubo.rotation_degrees.x = 72.0
	tubo.position = Vector3(0.0, -0.10, -0.26)
	_pivot.add_child(tubo)
	
	# Cabezal / boquilla
	_boquilla = Node3D.new()
	_boquilla.position = Vector3(0.0, -0.19, -0.52)
	_pivot.add_child(_boquilla)
	
	_cabezal_base = MeshInstance3D.new()
	var box_cab := BoxMesh.new()
	box_cab.size = Vector3(0.22, 0.045, 0.11)
	_cabezal_base.mesh = box_cab
	_cabezal_base.material_override = mat_plastico
	_cabezal_base.rotation_degrees.x = 12.0
	_boquilla.add_child(_cabezal_base)

func _physics_process(delta: float) -> void:
	if not _pivot or not _player:
		return
	
	if _encendida:
		_tiempo_vibracion += delta * (55.0 + float(nivel_mejora) * 8.0)
		var vib_x: float = sin(_tiempo_vibracion) * 0.003
		var vib_y: float = cos(_tiempo_vibracion * 1.3) * 0.003
		_pivot.position = _pos_base + Vector3(vib_x - 0.03, vib_y, -0.05)
		if _led_mat:
			_led_mat.emission_energy_multiplier = 2.0
		_procesar_succion(delta)
	else:
		_acumulador_succion = 0.0
		_pivot.position = _pivot.position.lerp(_pos_base, delta * 12.0)
		if _led_mat:
			_led_mat.emission_energy_multiplier = 0.0

func _procesar_succion(delta: float) -> void:
	_acumulador_succion += rate_aspirado * delta
	var cantidad: int = int(floor(_acumulador_succion))
	if cantidad <= 0:
		return
	
	var cuerpo: CharacterBody3D = _player.cuerpo
	var cabeza: Node3D = _player.cabeza
	if not cuerpo or not cabeza:
		return
	
	var adelante: Vector3 = -cuerpo.global_transform.basis.z
	var punto_suelo: Vector3 = cuerpo.global_position + adelante * 1.25
	
	var pitch: float = cabeza.rotation.x
	if pitch < -0.1:
		var extra: float = clamp((-pitch) * 1.1, 0.0, alcance_aspirado - 1.25)
		punto_suelo = cuerpo.global_position + adelante * (1.25 + extra)
	
	var gestores := get_tree().get_nodes_in_group("gestor_suciedad")
	if not gestores.is_empty():
		var gestor: Node = gestores[0]
		if gestor.has_method("intentar_aspirar"):
			var aspirados: int = gestor.intentar_aspirar(punto_suelo, _boquilla.global_position, radio_aspirado, cantidad)
			if aspirados > 0:
				_acumulador_succion -= float(aspirados)
			else:
				_acumulador_succion = min(_acumulador_succion, 1.0)

func aplicar_powerup(extra_rate: float, extra_radio: float, extra_alcance: float = 0.25) -> void:
	rate_aspirado += extra_rate
	radio_aspirado += extra_radio
	alcance_aspirado += extra_alcance
	nivel_mejora += 1
	_evolucionar_modelo_voxel(nivel_mejora)

func _crear_voxel_pieza(padre: Node3D, tam: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = tam
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	padre.add_child(mi)
	return mi

func _evolucionar_modelo_voxel(nivel: int) -> void:
	if not _pivot:
		return
	
	match nivel:
		1:
			# Nivel 1: Módulo condensador lateral + cable vóxel escalonado hacia el tubo
			_crear_voxel_pieza(_pivot, Vector3(0.045, 0.055, 0.09), Vector3(-0.048, -0.01, -0.04), _mat_modulo, Vector3(-18.0, 0.0, 0.0))
			var puntos_cable_1: Array[Vector3] = [
				Vector3(-0.048, -0.035, -0.09),
				Vector3(-0.042, -0.055, -0.14),
				Vector3(-0.030, -0.075, -0.19),
				Vector3(-0.018, -0.090, -0.24)
			]
			for p: Vector3 in puntos_cable_1:
				_crear_voxel_pieza(_pivot, Vector3(0.014, 0.014, 0.045), p, _mat_cable, Vector3(-18.0, 0.0, 0.0))
		
		2:
			# Nivel 2: Doble turbina superior sobre el tubo + bridas vóxel
			for lado: float in [-1.0, 1.0]:
				_crear_voxel_pieza(_pivot, Vector3(0.028, 0.032, 0.11), Vector3(lado * 0.032, -0.055, -0.20), _mat_modulo, Vector3(-18.0, 0.0, 0.0))
				# Aletas de refrigeración en vóxeles
				for i: int in range(3):
					_crear_voxel_pieza(_pivot, Vector3(0.034, 0.008, 0.016), Vector3(lado * 0.032, -0.038 - float(i) * 0.008, -0.17 - float(i) * 0.03), _mat_nucleo_glow, Vector3(-18.0, 0.0, 0.0))
		
		3:
			# Nivel 3: Ensanchamiento físico de la boquilla + cepillos laterales vóxel
			if _cabezal_base and _cabezal_base.mesh is BoxMesh:
				(_cabezal_base.mesh as BoxMesh).size = Vector3(0.32, 0.05, 0.12)
			for lado: float in [-1.0, 1.0]:
				_crear_voxel_pieza(_boquilla, Vector3(0.045, 0.035, 0.09), Vector3(lado * 0.175, -0.005, 0.0), _mat_modulo, Vector3(12.0, 0.0, 0.0))
				# Cable de potencia bajando por el tubo hasta el cabezal
				_crear_voxel_pieza(_pivot, Vector3(0.012, 0.012, 0.24), Vector3(lado * 0.025, -0.14, -0.39), _mat_cable, Vector3(-18.0, 0.0, 0.0))
		
		_:
			# Nivel 4+: Núcleo energético trasero + anillos vóxel en el tubo
			var idx_extra: int = nivel - 4
			var offset_z: float = float(idx_extra) * 0.045
			_crear_voxel_pieza(_pivot, Vector3(0.068, 0.068, 0.035), Vector3(0.0, 0.015, 0.08 + offset_z), _mat_nucleo_glow, Vector3(-18.0, 0.0, 0.0))
			_crear_voxel_pieza(_pivot, Vector3(0.076, 0.016, 0.042), Vector3(0.0, 0.052, 0.08 + offset_z), _mat_modulo, Vector3(-18.0, 0.0, 0.0))
			# Anillo conductor alrededor del tubo
			var pos_anillo := Vector3(0.0, -0.12 - float(idx_extra % 3) * 0.03, -0.32 - float(idx_extra % 3) * 0.08)
			_crear_voxel_pieza(_pivot, Vector3(0.056, 0.056, 0.018), pos_anillo, _mat_nucleo_glow, Vector3(-18.0, 0.0, 0.0))
