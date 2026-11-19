extends Node3D

@export var velocidad_andar: float = 5.5
@export var velocidad_correr: float = 9.5
@export var fuerza_salto: float = 5.2
@export var sensibilidad_raton: float = 0.0025

var _cuerpo: CharacterBody3D
var _cabeza: Node3D
var _camara: Camera3D
var _gravedad: float = 12.0

func _ready() -> void:
	_cuerpo = CharacterBody3D.new()
	_cuerpo.name = "CuerpoFinal"
	_cuerpo.position = Vector3(0.0, 0.2, 8.0)
	add_child(_cuerpo)
	
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	col.shape = cap
	col.position = Vector3(0.0, 0.9, 0.0)
	_cuerpo.add_child(col)
	
	_cabeza = Node3D.new()
	_cabeza.position = Vector3(0.0, 1.65, 0.0)
	_cuerpo.add_child(_cabeza)
	
	_camara = Camera3D.new()
	_camara.fov = 75.0
	_cabeza.add_child(_camara)
	call_deferred("_activar_camara")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _activar_camara() -> void:
	if _camara and _camara.is_inside_tree():
		_camara.make_current()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_cuerpo.rotate_y(-event.relative.x * sensibilidad_raton)
		_cabeza.rotate_x(-event.relative.y * sensibilidad_raton)
		_cabeza.rotation.x = clamp(_cabeza.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))

func _physics_process(delta: float) -> void:
	if not _cuerpo:
		return
	if not _cuerpo.is_on_floor():
		_cuerpo.velocity.y -= _gravedad * delta
	elif Input.is_key_pressed(KEY_SPACE):
		_cuerpo.velocity.y = fuerza_salto
	
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): input_dir.x += 1.0
	
	input_dir = input_dir.normalized()
	var vel: float = velocidad_correr if Input.is_key_pressed(KEY_SHIFT) else velocidad_andar
	var dir: Vector3 = (_cuerpo.transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	
	if dir != Vector3.ZERO:
		_cuerpo.velocity.x = dir.x * vel
		_cuerpo.velocity.z = dir.z * vel
	else:
		_cuerpo.velocity.x = move_toward(_cuerpo.velocity.x, 0.0, vel)
		_cuerpo.velocity.z = move_toward(_cuerpo.velocity.z, 0.0, vel)
	
	_cuerpo.move_and_slide()
