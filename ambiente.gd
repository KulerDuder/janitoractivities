extends Node3D

var _camara: Camera3D
var _tiempo: float = 0.0
var _pos_base := Vector3(6.5, 3.2, 16.0)
var _objetivo := Vector3(0.0, 4.5, -28.0)

func _ready() -> void:
	_crear_entorno_y_niebla()
	_crear_luz()
	_crear_camara()
	call_deferred("_orientar_camara")

func _process(delta: float) -> void:
	if not _camara or not _camara.is_inside_tree():
		return
	_tiempo += delta
	_camara.position.x = _pos_base.x + sin(_tiempo * 0.35) * 0.6
	_camara.position.y = _pos_base.y + cos(_tiempo * 0.5) * 0.15
	_camara.look_at(_objetivo, Vector3.UP)

func _crear_entorno_y_niebla() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.14, 0.14, 0.14)
	
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.25, 0.25)
	env.ambient_light_energy = 0.8
	
	env.fog_enabled = true
	env.fog_light_color = Color(0.18, 0.18, 0.18)
	env.fog_light_energy = 1.0
	env.fog_density = 0.028
	env.fog_sky_affect = 1.0
	
	world_env.environment = env
	add_child(world_env)

func _crear_luz() -> void:
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
	luz.light_color = Color(0.9, 0.9, 0.9)
	luz.light_energy = 1.1
	luz.shadow_enabled = true
	add_child(luz)

func _crear_camara() -> void:
	_camara = Camera3D.new()
	_camara.fov = 50.0
	_camara.position = _pos_base
	add_child(_camara)

func _orientar_camara() -> void:
	if _camara and _camara.is_inside_tree():
		_camara.look_at(_objetivo, Vector3.UP)
		_camara.make_current()
