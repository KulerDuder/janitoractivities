extends Node3D

@export var layer_index: int = 5

func _ready() -> void:
	_crear_capa_cine_antiguo()

func _crear_capa_cine_antiguo() -> void:
	var capa := CanvasLayer.new()
	capa.name = "CapaFiltroCine"
	capa.layer = layer_index
	add_child(capa)
	
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var shader := Shader.new()
	shader.code = """
	shader_type canvas_item;
	uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
	
	float rand(vec2 co) {
		return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
	}
	
	void fragment() {
		// Micro-temblor horizontal de proyector antiguo
		float jitter = (rand(vec2(floor(TIME * 24.0), 1.0)) - 0.5) * 0.0015;
		vec2 uv = SCREEN_UV + vec2(jitter, 0.0);
		
		vec4 tex = texture(screen_texture, clamp(uv, vec2(0.0), vec2(1.0)));
		
		// Blanco y negro de cine clásico sin aplastar los negros del interior
		float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
		lum = clamp((lum - 0.5) * 1.22 + 0.52, 0.0, 1.0);
		
		// Parpadeo de lámpara de proyector (flicker)
		float flicker = 0.94 + 0.06 * sin(TIME * 38.0) * cos(TIME * 17.0);
		lum *= flicker;
		
		// Grano de película dinámico
		float grano = (rand(uv * 400.0 + fract(TIME * 12.0)) - 0.5) * 0.12;
		lum += grano;
		
		// Rayas verticales esporádicas en la cinta
		float linea_x = floor(uv.x * 480.0);
		float tiempo_raya = floor(TIME * 14.0);
		float prob_raya = rand(vec2(linea_x, tiempo_raya));
		if (prob_raya > 0.9968) {
			lum -= 0.22;
		}
		
		// Viñeteado suave en las esquinas
		vec2 centro = SCREEN_UV - 0.5;
		float vineta = 1.0 - dot(centro, centro) * 1.05;
		lum *= clamp(vineta, 0.32, 1.0);
		
		COLOR = vec4(vec3(clamp(lum, 0.0, 1.0)), 1.0);
	}
	"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	capa.add_child(rect)
