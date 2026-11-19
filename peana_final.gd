extends Node3D

@export var tamano_peana: float = 90.0

func _ready() -> void:
	_crear_entorno()
	_crear_luz()
	_crear_suelo_enorme()

func _crear_entorno() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.16, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.45, 0.45)
	env.ambient_light_energy = 0.85
	
	env.fog_enabled = true
	env.fog_light_color = Color(0.20, 0.20, 0.20)
	env.fog_density = 0.022
	we.environment = env
	add_child(we)

func _crear_luz() -> void:
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	luz.light_energy = 1.25
	luz.shadow_enabled = true
	add_child(luz)

func _crear_suelo_enorme() -> void:
	var sb := StaticBody3D.new()
	sb.name = "PeanaGigante"
	add_child(sb)
	
	# Textura procedural de losas grandes
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y: int in range(64):
		for x: int in range(64):
			var borde: bool = (x < 2 or y < 2)
			var c := Color(0.24, 0.24, 0.24) if borde else Color(0.46, 0.46, 0.46)
			img.set_pixel(x, y, c)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.35, 0.35, 0.35)
	mat.roughness = 0.85
	
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(tamano_peana, 1.0, tamano_peana)
	mi.mesh = box
	mi.position = Vector3(0.0, -0.5, 0.0)
	mi.material_override = mat
	sb.add_child(mi)
	
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(tamano_peana, 1.0, tamano_peana)
	col.shape = shape
	col.position = Vector3(0.0, -0.5, 0.0)
	sb.add_child(col)
	
	# Murete perimetral bajo para no salirte de la peana
	var m := tamano_peana * 0.5
	var bordes: Array[Array] = [
		[Vector3(0.0, 0.75, -m), Vector3(tamano_peana, 1.5, 1.0)],
		[Vector3(0.0, 0.75,  m), Vector3(tamano_peana, 1.5, 1.0)],
		[Vector3(-m, 0.75, 0.0), Vector3(1.0, 1.5, tamano_peana)],
		[Vector3( m, 0.75, 0.0), Vector3(1.0, 1.5, tamano_peana)]
	]
	for b: Array in bordes:
		var mb := MeshInstance3D.new()
		var bmesh := BoxMesh.new()
		bmesh.size = b[1]
		mb.mesh = bmesh
		mb.position = b[0]
		mb.material_override = mat
		sb.add_child(mb)
		
		var cb := CollisionShape3D.new()
		var bshape := BoxShape3D.new()
		bshape.size = b[1]
		cb.shape = bshape
		cb.position = b[0]
		sb.add_child(cb)
