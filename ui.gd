extends Node3D

@export_file("*.tscn") var ruta_escena_mundo: String = "res://Mundo.tscn"

var _capa_ui: CanvasLayer

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_capa_ui = CanvasLayer.new()
	add_child(_capa_ui)
	_crear_filtro_cine_antiguo()
	_crear_interfaz()

func _crear_filtro_cine_antiguo() -> void:
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
		float jitter = (rand(vec2(floor(TIME * 24.0), 1.0)) - 0.5) * 0.0018;
		vec2 uv = SCREEN_UV + vec2(jitter, 0.0);
		
		vec4 tex = texture(screen_texture, clamp(uv, vec2(0.0), vec2(1.0)));
		
		// Blanco y negro de alto contraste tipo celuloide clásico
		float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
		lum = clamp((lum - 0.5) * 1.45 + 0.5, 0.0, 1.0);
		
		// Parpadeo de lámpara de proyector (flicker)
		float flicker = 0.92 + 0.08 * sin(TIME * 38.0) * cos(TIME * 17.0);
		lum *= flicker;
		
		// Grano de película dinámico
		float grano = (rand(uv * 400.0 + fract(TIME * 12.0)) - 0.5) * 0.14;
		lum += grano;
		
		// Rayas verticales esporádicas en la cinta
		float linea_x = floor(uv.x * 480.0);
		float tiempo_raya = floor(TIME * 14.0);
		float prob_raya = rand(vec2(linea_x, tiempo_raya));
		if (prob_raya > 0.9965) {
			lum -= 0.25;
		}
		
		// Viñeteado oscuro pronunciado en las esquinas
		vec2 centro = SCREEN_UV - 0.5;
		float vineta = 1.0 - dot(centro, centro) * 1.35;
		lum *= clamp(vineta, 0.15, 1.0);
		
		COLOR = vec4(vec3(clamp(lum, 0.0, 1.0)), 1.0);
	}
	"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	_capa_ui.add_child(rect)

func _crear_interfaz() -> void:
	var contenedor := VBoxContainer.new()
	contenedor.set_anchors_preset(Control.PRESET_FULL_RECT)
	contenedor.alignment = BoxContainer.ALIGNMENT_CENTER
	contenedor.add_theme_constant_override("separation", 36)
	_capa_ui.add_child(contenedor)
	
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 120)
	contenedor.add_child(spacer)
	
	var titulo := Label.new()
	titulo.text = "JANITOR ACTIVITIES"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 56)
	titulo.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	titulo.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	titulo.add_theme_constant_override("shadow_offset_x", 4)
	titulo.add_theme_constant_override("shadow_offset_y", 4)
	contenedor.add_child(titulo)
	
	var center_btn := CenterContainer.new()
	contenedor.add_child(center_btn)
	
	var boton := Button.new()
	boton.text = "  EMPEZAR  "
	boton.custom_minimum_size = Vector2(220, 54)
	boton.add_theme_font_size_override("font_size", 24)
	boton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.05, 0.05, 0.05, 0.88)
	style_normal.set_border_width_all(2)
	style_normal.border_color = Color(0.9, 0.9, 0.9)
	
	var style_hover := style_normal.duplicate()
	style_hover.bg_color = Color(0.9, 0.9, 0.9, 0.95)
	
	boton.add_theme_stylebox_override("normal", style_normal)
	boton.add_theme_stylebox_override("hover", style_hover)
	boton.add_theme_stylebox_override("pressed", style_hover)
	boton.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	boton.add_theme_color_override("font_hover_color", Color(0.05, 0.05, 0.05))
	boton.add_theme_color_override("font_pressed_color", Color(0.05, 0.05, 0.05))
	
	boton.pressed.connect(_al_pulsar_empezar)
	center_btn.add_child(boton)

func _al_pulsar_empezar() -> void:
	if ResourceLoader.exists(ruta_escena_mundo):
		get_tree().change_scene_to_file(ruta_escena_mundo)
	else:
		push_warning("Aún no existe la escena: " + ruta_escena_mundo)
