extends Node3D

@export var cantidad_powerups: int = 5
@export var bonus_rate_por_nivel: float = 3.5   # +3.5 vóxeles/seg por módulo
@export var bonus_radio_por_nivel: float = 0.22  # +0.22m de radio de succión por módulo
@export var bonus_alcance_por_nivel: float = 0.25

const SAMPLE_RATE: int = 22050

var _items: Array[Dictionary] = []
var _tiempo: float = 0.0
var _rng := RandomNumberGenerator.new()
var _audio_pickup: AudioStreamPlayer
var _label_notificacion: Label
var _timer_notif: float = 0.0

var _nombres_modulos: Array[String] = [
	"AUXILIARY CAPACITOR COIL",
	"TWIN TURBINE BOOSTER",
	"WIDE-NOZZLE INTAKE ARRAY",
	"OVERCLOCKED PLASMA CORE",
	"INDUSTRIAL VORTEX MODULE"
]

func _ready() -> void:
	_rng.seed = 5150
	_preparar_audio_pickup()
	_crear_hud_notificacion()
	call_deferred("_generar_powerups_en_mapa")

func _generar_powerups_en_mapa() -> void:
	var mapas := get_tree().get_nodes_in_group("mapa_instituto")
	var mapa: Node = mapas[0] if not mapas.is_empty() else null
	
	# Puntos estratégicos dentro de aulas y extremos de pasillos (lejos de la Janitor Office)
	var candidatos: Array[Vector3] = [
		Vector3(-22.0, 0.85, -19.0), # Classroom 102
		Vector3(22.0,  0.85, -19.0), # Storage Room
		Vector3(-22.0, 0.85, -39.0), # Science Lab
		Vector3(0.0,   0.85, -39.0), # Library
		Vector3(22.0,  0.85, -39.0), # Gymnasium
		Vector3(-14.5, 0.85, -39.0), # Classroom 201
		Vector3(14.5,  0.85, -19.0), # Classroom 103
		Vector3(7.5,   0.85, -39.0)  # Art Room
	]
	
	# Barajamos candidatos con nuestra semilla
	for i: int in range(candidatos.size() - 1, 0, -1):
		var j: int = _rng.randi() % (i + 1)
		var tmp: Vector3 = candidatos[i]
		candidatos[i] = candidatos[j]
		candidatos[j] = tmp
	
	var creados: int = 0
	for pos: Vector3 in candidatos:
		if creados >= cantidad_powerups:
			break
		if mapa and (mapa.esta_bloqueado(pos.x, pos.z) or mapa.es_zona_segura(pos)):
			continue
		_instanciar_powerup(pos, creados)
		creados += 1

func _instanciar_powerup(pos: Vector3, indice: int) -> void:
	var raiz := Node3D.new()
	raiz.name = "PowerUpModulo_" + str(indice)
	raiz.position = pos
	add_child(raiz)
	
	var mat_nucleo := StandardMaterial3D.new()
	mat_nucleo.albedo_color = Color(0.55, 0.94, 1.0)
	mat_nucleo.emission_enabled = true
	mat_nucleo.emission = Color(0.45, 0.90, 1.0)
	mat_nucleo.emission_energy_multiplier = 1.8
	
	var mat_carcasa := StandardMaterial3D.new()
	mat_carcasa.albedo_color = Color(0.25, 0.28, 0.32)
	mat_carcasa.metallic = 0.6
	mat_carcasa.roughness = 0.35
	
	var mat_cable := StandardMaterial3D.new()
	mat_cable.albedo_color = Color(0.85, 0.35, 0.22)
	
	# Núcleo central vóxel
	var nucleo := MeshInstance3D.new()
	var box_n := BoxMesh.new()
	box_n.size = Vector3(0.26, 0.26, 0.26)
	nucleo.mesh = box_n
	nucleo.material_override = mat_nucleo
	raiz.add_child(nucleo)
	
	# Aro orbital de vóxeles (módulos y cables) alrededor del núcleo
	var orbita := Node3D.new()
	raiz.add_child(orbita)
	
	for k: int in range(4):
		var ang: float = (TAU / 4.0) * float(k)
		var pieza := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.11, 0.16, 0.11) if (k % 2 == 0) else Vector3(0.08, 0.08, 0.22)
		pieza.mesh = b
		pieza.material_override = mat_carcasa if (k % 2 == 0) else mat_cable
		pieza.position = Vector3(cos(ang) * 0.28, 0.0, sin(ang) * 0.28)
		orbita.add_child(pieza)
	
	# Área de recogida
	var area := Area3D.new()
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.95
	col.shape = sphere
	area.add_child(col)
	raiz.add_child(area)
	
	var datos_item := {
		"raiz": raiz,
		"nucleo": nucleo,
		"orbita": orbita,
		"base_y": pos.y,
		"fase": float(indice) * 1.3,
		"recogido": false
	}
	_items.append(datos_item)
	
	area.body_entered.connect(func(body: Node3D) -> void:
		if not datos_item["recogido"] and body.is_in_group("jugador"):
			_recoger_powerup(datos_item)
	)

func _recoger_powerup(item: Dictionary) -> void:
	item["recogido"] = true
	item["raiz"].visible = false
	item["raiz"].queue_free()
	
	var nivel_actual: int = 1
	var aspiradoras := get_tree().get_nodes_in_group("aspiradora")
	if not aspiradoras.is_empty() and aspiradoras[0].has_method("aplicar_powerup"):
		aspiradoras[0].aplicar_powerup(bonus_rate_por_nivel, bonus_radio_por_nivel, bonus_alcance_por_nivel)
		nivel_actual = aspiradoras[0].nivel_mejora
	
	if _audio_pickup and is_instance_valid(_audio_pickup):
		_audio_pickup.play()
	
	var nombre_mod: String = _nombres_modulos[(nivel_actual - 1) % _nombres_modulos.size()]
	_mostrar_notificacion("VACUUM UPGRADED (LV.%d): %s\n+SUCTION RADIUS  |  +SUCTION SPEED" % [nivel_actual, nombre_mod])

func _process(delta: float) -> void:
	_tiempo += delta
	
	if _timer_notif > 0.0:
		_timer_notif -= delta
		if _timer_notif <= 0.0 and _label_notificacion:
			_label_notificacion.visible = false
	
	for item: Dictionary in _items:
		if item["recogido"] or not is_instance_valid(item["raiz"]):
			continue
		var raiz: Node3D = item["raiz"]
		var nucleo: Node3D = item["nucleo"]
		var orbita: Node3D = item["orbita"]
		var fase: float = item["fase"]
		
		raiz.position.y = item["base_y"] + sin(_tiempo * 2.6 + fase) * 0.12
		nucleo.rotation.y += delta * 1.8
		nucleo.rotation.x += delta * 0.9
		orbita.rotation.y -= delta * 2.8

func _crear_hud_notificacion() -> void:
	var capa := CanvasLayer.new()
	capa.name = "HUD_PowerUps"
	capa.layer = 9
	add_child(capa)
	
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	center.grow_vertical = Control.GROW_DIRECTION_BEGIN
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(center)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_bottom", 95)
	center.add_child(margin)
	
	_label_notificacion = Label.new()
	_label_notificacion.visible = false
	_label_notificacion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_notificacion.add_theme_font_size_override("font_size", 20)
	_label_notificacion.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0))
	_label_notificacion.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	_label_notificacion.add_theme_constant_override("shadow_offset_x", 2)
	_label_notificacion.add_theme_constant_override("shadow_offset_y", 2)
	margin.add_child(_label_notificacion)

func _mostrar_notificacion(texto: String) -> void:
	if not _label_notificacion:
		return
	_label_notificacion.text = texto
	_label_notificacion.visible = true
	_timer_notif = 4.0

# Sintetiza un arpegio ascendente tecnológico de 3 notas al recoger el módulo
func _preparar_audio_pickup() -> void:
	var dur: float = 0.36
	var muestras: int = int(SAMPLE_RATE * dur)
	var datos := PackedByteArray()
	datos.resize(muestras * 2)
	
	var notas: Array[float] = [523.25, 659.25, 1046.50] # Do5 - Mi5 - Do6
	var fase: float = 0.0
	for i: int in range(muestras):
		var t: float = float(i) / float(SAMPLE_RATE)
		var idx_nota: int = clamp(int(t / (dur / 3.0)), 0, 2)
		var t_local: float = fmod(t, dur / 3.0)
		var freq: float = notas[idx_nota]
		fase += (TAU * freq) / float(SAMPLE_RATE)
		
		var env: float = clamp(t_local / 0.008, 0.0, 1.0) * exp(-t_local * 14.0)
		var onda: float = sin(fase) * 0.7 + sin(fase * 2.0) * 0.25
		var s: float = clamp(onda * env * 0.65, -1.0, 1.0)
		datos.encode_s16(i * 2, int(s * 32767.0))
	
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = datos
	
	_audio_pickup = AudioStreamPlayer.new()
	_audio_pickup.stream = wav
	_audio_pickup.volume_db = -6.0
	add_child(_audio_pickup)
