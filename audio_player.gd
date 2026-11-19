extends Node3D

@export var volumen_pasos_db: float = -8.0
@export var volumen_aspiradora_db: float = -18.0

const SAMPLE_RATE: int = 22050

var _player_pasos: AudioStreamPlayer
var _player_aspiradora: AudioStreamPlayer
var _wav_andar: AudioStreamWAV
var _wav_correr: AudioStreamWAV
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 13579
	_wav_andar = _sintetizar_paso(false)
	_wav_correr = _sintetizar_paso(true)
	
	_player_pasos = AudioStreamPlayer.new()
	_player_pasos.name = "SonidoPasos"
	_player_pasos.volume_db = volumen_pasos_db
	add_child(_player_pasos)
	
	_player_aspiradora = AudioStreamPlayer.new()
	_player_aspiradora.name = "SonidoAspiradora"
	_player_aspiradora.stream = _sintetizar_loop_aspiradora()
	_player_aspiradora.volume_db = volumen_aspiradora_db
	add_child(_player_aspiradora)
	
	var padre := get_parent()
	if padre:
		if padre.has_signal("paso_dado"):
			padre.paso_dado.connect(_reproducir_paso)
		if padre.has_signal("estado_aspiradora_cambiado"):
			padre.estado_aspiradora_cambiado.connect(_actualizar_sonido_aspiradora)

func _reproducir_paso(corriendo: bool, pie_derecho: bool) -> void:
	if not _player_pasos:
		return
	_player_pasos.stream = _wav_correr if corriendo else _wav_andar
	# Ligera variación entre pie izquierdo/derecho para que no suene robótico
	var base_pitch: float = 1.04 if pie_derecho else 0.96
	_player_pasos.pitch_scale = base_pitch + _rng.randf_range(-0.04, 0.04)
	_player_pasos.volume_db = volumen_pasos_db + (3.5 if corriendo else 0.0)
	_player_pasos.play()

func _actualizar_sonido_aspiradora(encendida: bool) -> void:
	if not _player_aspiradora:
		return
	if encendida and not _player_aspiradora.playing:
		_player_aspiradora.play()
	elif not encendida and _player_aspiradora.playing:
		_player_aspiradora.stop()

# Sintetiza un golpe corto y cálido de suela sobre baldosa (sin archivos externos)
func _sintetizar_paso(es_carrera: bool) -> AudioStreamWAV:
	var duracion: float = 0.095 if es_carrera else 0.12
	var num_muestras: int = int(SAMPLE_RATE * duracion)
	var datos := PackedByteArray()
	datos.resize(num_muestras * 2) # 16-bit mono
	
	var filtro_lp: float = 0.0
	var freq_impacto: float = 105.0 if es_carrera else 82.0
	
	for i: int in range(num_muestras):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env: float = exp(-t * (48.0 if es_carrera else 38.0))
		
		# Golpe grave de talón + textura suave de suela filtrada
		var golpe: float = sin(TAU * freq_impacto * t * (1.0 - t * 2.5)) * 0.75
		var ruido: float = _rng.randf_range(-1.0, 1.0)
		filtro_lp = lerp(filtro_lp, ruido, 0.18 if es_carrera else 0.12)
		
		var muestra: float = clamp((golpe + filtro_lp * 0.65) * env * 0.7, -1.0, 1.0)
		var valor_int: int = int(muestra * 32767.0)
		datos.encode_s16(i * 2, valor_int)
	
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = datos
	return wav

# Sintetiza un bucle corto y suave del motor de la aspiradora
func _sintetizar_loop_aspiradora() -> AudioStreamWAV:
	var duracion: float = 0.5
	var num_muestras: int = int(SAMPLE_RATE * duracion)
	var datos := PackedByteArray()
	datos.resize(num_muestras * 2)
	
	var filtro: float = 0.0
	for i: int in range(num_muestras):
		var t: float = float(i) / float(SAMPLE_RATE)
		var motor: float = sin(TAU * 60.0 * t) * 0.35 + sin(TAU * 120.0 * t) * 0.2
		var aire: float = _rng.randf_range(-1.0, 1.0)
		filtro = lerp(filtro, aire, 0.08)
		var muestra: float = clamp((motor + filtro * 0.45) * 0.45, -1.0, 1.0)
		datos.encode_s16(i * 2, int(muestra * 32767.0))
	
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = num_muestras
	wav.data = datos
	return wav
