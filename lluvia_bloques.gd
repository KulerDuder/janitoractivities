extends Node3D

@export var max_bloques: int = 8000
@export var bloques_por_segundo: float = 95.0
@export var tamano_bloque: float = 0.55

const RADIO_LLUVIA: float = 38.0
const ALTURA_SPAWN: float = 26.0

var _multimesh: MultiMesh
var _mm_inst: MultiMeshInstance3D

# Altura acumulada por celda de rejilla (Vector2i -> int número de bloques apilados)
var _alturas_grid: Dictionary = {}

# Bloques cayendo actualmente
var _cayendo_idx: Array[int] = []
var _cayendo_y: PackedFloat32Array = PackedFloat32Array()
var _cayendo_vel: PackedFloat32Array = PackedFloat32Array()
var _cayendo_destino_y: PackedFloat32Array = PackedFloat32Array()
var _cayendo_x: PackedFloat32Array = PackedFloat32Array()
var _cayendo_z: PackedFloat32Array = PackedFloat32Array()

var _usados: int = 0
var _acumulador_spawn: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 77777
	_inicializar_multimesh()

func _inicializar_multimesh() -> void:
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	
	var box := BoxMesh.new()
	box.size = Vector3(tamano_bloque * 0.96, tamano_bloque * 0.96, tamano_bloque * 0.96)
	_multimesh.mesh = box
	_multimesh.instance_count = max_bloques
	
	# Ocultamos todos los bloques al inicio
	var oculto := Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0.0, -100.0, 0.0))
	for i: int in range(max_bloques):
		_multimesh.set_instance_transform(i, oculto)
	
	_mm_inst = MultiMeshInstance3D.new()
	_mm_inst.name = "MultiMeshLluvia"
	_mm_inst.multimesh = _multimesh
	_mm_inst.extra_cull_margin = 100.0
	
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	_mm_inst.material_override = mat
	add_child(_mm_inst)

func _process(delta: float) -> void:
	if _usados < max_bloques:
		_acumulador_spawn += bloques_por_segundo * delta
		var nuevos: int = int(floor(_acumulador_spawn))
		if nuevos > 0:
			_acumulador_spawn -= float(nuevos)
			for n: int in range(nuevos):
				if _usados >= max_bloques:
					break
				_generar_bloque_cayendo()
	
	# Actualizar caída de bloques en vuelo
	var i: int = _cayendo_idx.size() - 1
	while i >= 0:
		var idx: int = _cayendo_idx[i]
		var vel: float = _cayendo_vel[i] + 18.0 * delta
		var y: float = _cayendo_y[i] - vel * delta
		var dest_y: float = _cayendo_destino_y[i]
		var px: float = _cayendo_x[i]
		var pz: float = _cayendo_z[i]
		
		if y <= dest_y:
			# Aterriza apilado en su columna
			_multimesh.set_instance_transform(idx, Transform3D(Basis(), Vector3(px, dest_y, pz)))
			_cayendo_idx.remove_at(i)
			_cayendo_y.remove_at(i)
			_cayendo_vel.remove_at(i)
			_cayendo_destino_y.remove_at(i)
			_cayendo_x.remove_at(i)
			_cayendo_z.remove_at(i)
		else:
			_cayendo_vel[i] = vel
			_cayendo_y[i] = y
			_multimesh.set_instance_transform(idx, Transform3D(Basis(), Vector3(px, y, pz)))
		i -= 1

func _generar_bloque_cayendo() -> void:
	var idx: int = _usados
	_usados += 1
	
	var gx: int = int(round(_rng.randf_range(-RADIO_LLUVIA, RADIO_LLUVIA) / tamano_bloque))
	var gz: int = int(round(_rng.randf_range(-RADIO_LLUVIA, RADIO_LLUVIA) / tamano_bloque))
	var celda := Vector2i(gx, gz)
	
	var piso_actual: int = _alturas_grid.get(celda, 0)
	_alturas_grid[celda] = piso_actual + 1
	
	var dest_y: float = (float(piso_actual) + 0.5) * tamano_bloque
	var px: float = float(gx) * tamano_bloque
	var pz: float = float(gz) * tamano_bloque
	var spawn_y: float = ALTURA_SPAWN + _rng.randf_range(0.0, 10.0)
	
	var tono: float = _rng.randf_range(0.18, 0.88)
	_multimesh.set_instance_color(idx, Color(tono, tono, tono))
	_multimesh.set_instance_transform(idx, Transform3D(Basis(), Vector3(px, spawn_y, pz)))
	
	_cayendo_idx.append(idx)
	_cayendo_y.append(spawn_y)
	_cayendo_vel.append(_rng.randf_range(2.0, 6.0))
	_cayendo_destino_y.append(dest_y)
	_cayendo_x.append(px)
	_cayendo_z.append(pz)
