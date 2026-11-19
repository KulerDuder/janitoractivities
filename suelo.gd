extends Node3D

func _ready() -> void:
	_generar_suelo()

func _crear_caja(tamano: Vector3, pos: Vector3, tono_gris: float) -> void:
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = tamano
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(tono_gris, tono_gris, tono_gris)
	mat.roughness = 0.9
	
	mesh_inst.mesh = box
	mesh_inst.material_override = mat
	mesh_inst.position = pos
	add_child(mesh_inst)

func _generar_suelo() -> void:
	# Explanada principal
	_crear_caja(Vector3(180.0, 0.5, 180.0), Vector3(0.0, -0.25, 0.0), 0.12)
	
	# Acera frontal junto al instituto
	_crear_caja(Vector3(48.0, 0.2, 8.0), Vector3(0.0, 0.1, -18.0), 0.35)
	
	# Camino central de acceso
	_crear_caja(Vector3(6.0, 0.15, 36.0), Vector3(0.0, 0.075, 2.0), 0.32)
	
	# Líneas del patio / aparcamiento
	for i in range(-4, 5):
		if i == 0:
			continue
		_crear_caja(Vector3(0.2, 0.05, 5.0), Vector3(i * 4.5, 0.03, 5.0), 0.65)
