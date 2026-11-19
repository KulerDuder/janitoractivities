extends Node3D

@export var tamano_suelo: float = 200.0

func _ready() -> void:
	_generar_gran_suelo()
	_generar_luz_provisional()

func _generar_gran_suelo() -> void:
	var cuerpo := StaticBody3D.new()
	cuerpo.name = "SueloEstatico"
	add_child(cuerpo)
	
	# Malla visual
	var mesh_inst := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(tamano_suelo, 1.0, tamano_suelo)
	mesh_inst.mesh = box_mesh
	mesh_inst.position = Vector3(0.0, -0.5, 0.0)
	mesh_inst.material_override = _crear_material_cuadricula()
	cuerpo.add_child(mesh_inst)
	
	# Colisión física
	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(tamano_suelo, 1.0, tamano_suelo)
	col.shape = box_shape
	col.position = Vector3(0.0, -0.5, 0.0)
	cuerpo.add_child(col)

func _crear_material_cuadricula() -> StandardMaterial3D:
	# Generamos una textura procedural de baldosas para notar el desplazamiento
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y: int in range(64):
		for x: int in range(64):
			var borde: bool = (x < 2 or y < 2)
			var c := Color(0.22, 0.22, 0.22) if borde else Color(0.38, 0.38, 0.38)
			img.set_pixel(x, y, c)
	
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
	mat.roughness = 0.85
	return mat

func _generar_luz_provisional() -> void:
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-45.0, -35.0, 0.0)
	luz.light_energy = 1.0
	luz.shadow_enabled = true
	add_child(luz)
