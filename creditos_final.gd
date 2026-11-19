extends Node3D

@export var velocidad_scroll: float = 48.0
@export_file("*.mp3", "*.ogg", "*.wav") var musica_mp3: String = "res://mendelssohn.mp3"
@export var volumen_musica_db: float = -4.0
@export var volumen_vinilo_db: float = -18.0
@export_file("*.tscn") var ruta_intro: String = "res://Intro.tscn"

const BUS_GRAMOFONO: String = "GramofonoAntiguo"
const SAMPLE_RATE: int = 22050

var _label_creditos: Label
var _alto_pantalla: float = 720.0
var _reproductor_mp3: AudioStreamPlayer
var _reproductor_vinilo: AudioStreamPlayer
var _tiempo: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 1924
	_configurar_bus_gramofono()
	_iniciar_musica_y_vinilo()
	_crear_ui_creditos()

func _configurar_bus_gramofono() -> void:
	# Creamos un bus de audio dedicado con efectos de época (funciona en WebGL)
	var bus_idx: int = AudioServer.get_bus_index(BUS_GRAMOFONO)
	if bus_idx == -1:
		AudioServer.add_bus()
		bus_idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(bus_idx, BUS_GRAMOFONO)
		AudioServer.set_bus_send(bus_idx, "Master")
		
		# 1. Filtro paso-alto para quitar graves modernos (~320 Hz)
		var hp := AudioEffectHighPassFilter.new()
		hp.cutoff_hz = 320.0
		hp.resonance = 0.7
		AudioServer.add_bus_effect(bus_idx, hp)
		
		# 2. Filtro paso-bajo estilo bocina de gramófono (~2600 Hz)
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 2600.0
		lp.resonance = 0.85
		AudioServer.add_bus_effect(bus_idx, lp)
		
		# 3. Saturación cálida de válvula/cera antigua
		var dist := AudioEffectDistortion.new()
		dist.mode = AudioEffectDistortion.MODE_OVERDRIVE
		dist.drive = 0.22
		dist.post_gain = -2.0
		AudioServer.add_bus_effect(bus_idx, dist)

func _iniciar_musica_y_vinilo() -> void:
	# 1. Reproductor para tu archivo MP3 en bucle infinito
	if ResourceLoader.exists(musica_mp3):
		var stream: AudioStream = load(musica_mp3)
		if stream is AudioStreamMP3:
			stream.loop = true
		elif stream is AudioStreamOggVorbis:
			stream.loop = true
		
		_reproductor_mp3 = AudioStreamPlayer.new()
		_reproductor_mp3.name = "MusicaMendelssohn"
		_reproductor_mp3.stream = stream
		_reproductor_mp3.bus = BUS_GRAMOFONO
		_reproductor_mp3.volume_db = volumen_musica_db
		add_child(_reproductor_mp3)
		_reproductor_mp3.play()
	else:
		push_warning("No se encontró el archivo de audio: " + musica_mp3)
	
	# 2. Pista sutil de crepitación de aguja de vinilo/pizarra encima
	_reproductor_vinilo = AudioStreamPlayer.new()
	_reproductor_vinilo.name = "CrepitacionVinilo"
	_reproductor_vinilo.stream = _sintetizar_ruido_vinilo()
	_reproductor_vinilo.bus = BUS_GRAMOFONO
	_reproductor_vinilo.volume_db = volumen_vinilo_db
	add_child(_reproductor_vinilo)
	_reproductor_vinilo.play()

func _sintetizar_ruido_vinilo() -> AudioStreamWAV:
	var duracion: float = 2.0
	var muestras: int = int(SAMPLE_RATE * duracion)
	var datos := PackedByteArray()
	datos.resize(muestras * 2)
	
	for i: int in range(muestras):
		var ruido_base: float = _rng.randf_range(-1.0, 1.0) * 0.08
		var chasquido: float = 0.0
		if _rng.randf() > 0.9975:
			chasquido = _rng.randf_range(-0.75, 0.75)
		var val: float = clamp(ruido_base + chasquido, -1.0, 1.0)
		datos.encode_s16(i * 2, int(val * 32767.0))
	
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = muestras
	wav.data = datos
	return wav

func _crear_ui_creditos() -> void:
	var capa := CanvasLayer.new()
	capa.name = "CapaCreditos"
	capa.layer = 10 # Por encima del filtro de cine para que el texto sea nítido
	add_child(capa)
	
	var texto_mock: String = """JANITOR ACTIVITIES
- MARRIED TO THE JOB -


DIRECTED BY
KULER DUDER


STARRING
THE JANITOR
& HIS BELOVED VACUUM CLEANER


VOXEL DUST WRANGLERS
THOUSANDS OF TINY CUBES OF PURE DIRT


SPECIAL THANKS
ENERGY SODA INC.
"KEEPING NIGHT SHIFTS AWAKE SINCE 1924"


CLEANING REPORT
ALL HALLWAYS: SPOTLESS
ALL CLASSROOMS: VACUUMED
JANITOR OFFICE: SAFE


...WAIT A SECOND.
WHERE ARE ALL THESE NEW BLOCKS COMING FROM?!


TILL DEATH DO US PART.
THE SHIFT NEVER TRULY ENDS.


THANK YOU FOR PLAYING
JANITOR ACTIVITIES


[ PRESS R TO RETURN TO TITLE ]
"""
	
	_label_creditos = Label.new()
	_label_creditos.text = texto_mock
	_label_creditos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_creditos.add_theme_font_size_override("font_size", 28)
	_label_creditos.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	_label_creditos.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
	_label_creditos.add_theme_constant_override("shadow_offset_x", 3)
	_label_creditos.add_theme_constant_override("shadow_offset_y", 3)
	
	_label_creditos.set_anchors_preset(Control.PRESET_TOP_WIDE)
	capa.add_child(_label_creditos)
	
	call_deferred("_reiniciar_posicion_abajo")

func _reiniciar_posicion_abajo() -> void:
	_alto_pantalla = get_viewport().get_visible_rect().size.y
	_label_creditos.position.y = _alto_pantalla + 40.0

func _process(delta: float) -> void:
	_tiempo += delta
	
	# Wow & Flutter: leve oscilación de velocidad en tiempo real sobre tu MP3 como un disco viejo
	if _reproductor_mp3 and _reproductor_mp3.playing:
		var wow: float = sin(_tiempo * 3.1) * 0.012 + cos(_tiempo * 11.4) * 0.005
		_reproductor_mp3.pitch_scale = 0.975 + wow
	
	if not _label_creditos:
		return
	
	_label_creditos.position.y -= velocidad_scroll * delta
	var alto_texto: float = _label_creditos.size.y
	if alto_texto <= 0.0:
		alto_texto = 900.0
	
	# Bucle infinito de créditos
	if _label_creditos.position.y < -alto_texto - 40.0:
		_alto_pantalla = get_viewport().get_visible_rect().size.y
		_label_creditos.position.y = _alto_pantalla + 40.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		if ResourceLoader.exists(ruta_intro):
			get_tree().change_scene_to_file(ruta_intro)
