class_name MonstruoAnimador
extends RefCounted

var _skel: Skeleton3D
var _bones: Dictionary = {} # nombre -> idx
var _rest_poses: Dictionary = {} # idx -> Transform3D

# Longitudes reales medidas del esqueleto (con factor de alargamiento)
var _len_upper_arm: float = 0.42
var _len_forearm: float = 0.42
var _len_thigh: float = 0.50
var _len_shin: float = 0.48

var _fase_marcha: float = 0.0
var _boca_abierta: float = 0.0
var _modo_jumpscare: bool = false
var _tiempo: float = 0.0

func _init(skel: Skeleton3D, factor_alargamiento: float = 1.28) -> void:
	_skel = skel
	_mapear_huesos(factor_alargamiento)

func _mapear_huesos(factor_alargamiento: float) -> void:
	var nombres: Array[String] = [
		"root", "pelvis", "spine_lower", "spine_upper", "neck", "head", "jaw",
		"shoulder_L", "upper_arm_L", "forearm_L", "hand_L",
		"shoulder_R", "upper_arm_R", "forearm_R", "hand_R",
		"thigh_L", "shin_L", "thigh_R", "shin_R"
	]
	for n: String in nombres:
		var idx: int = _skel.find_bone(n)
		_bones[n] = idx
		if idx != -1:
			_rest_poses[idx] = _skel.get_bone_rest(idx)
	
	# Calculamos longitudes base desde las posiciones de reposo y aplicamos alargamiento inquietante
	_len_upper_arm = _dist_huesos("upper_arm_L", "forearm_L", 0.36) * factor_alargamiento
	_len_forearm = _dist_huesos("forearm_L", "hand_L", 0.36) * factor_alargamiento
	_len_thigh = _dist_huesos("thigh_L", "shin_L", 0.45) * factor_alargamiento
	_len_shin = 0.44 * factor_alargamiento
	
	# Estiramos visualmente los segmentos de extremidades en el esqueleto
	for b_name: String in ["upper_arm_L", "forearm_L", "upper_arm_R", "forearm_R", "thigh_L", "shin_L", "thigh_R", "shin_R"]:
		var idx: int = _bones.get(b_name, -1)
		if idx != -1:
			var rest: Transform3D = _rest_poses[idx]
			# Estiramos el eje principal del hueso manteniendo el grosor
			rest.basis = rest.basis.scaled(Vector3(0.92, factor_alargamiento, 0.92))
			_rest_poses[idx] = rest
			_skel.set_bone_pose_scale(idx, Vector3(0.92, factor_alargamiento, 0.92))

func _dist_huesos(b1: String, b2: String, fallback: float) -> float:
	var i1: int = _bones.get(b1, -1)
	var i2: int = _bones.get(b2, -1)
	if i1 == -1 or i2 == -1:
		return fallback
	var p1: Vector3 = _skel.get_bone_global_rest(i1).origin
	var p2: Vector3 = _skel.get_bone_global_rest(i2).origin
	var d: float = p1.distance_to(p2)
	return d if d > 0.05 else fallback

func actualizar(delta: float, velocidad_lineal: float, persiguiendo: bool, jumpscare: bool) -> void:
	if not _skel:
		return
	_tiempo += delta
	_modo_jumpscare = jumpscare
	
	if jumpscare:
		_animar_jumpscare()
		return
	
	var moviendose: bool = velocidad_lineal > 0.15
	var freq: float = (2.6 if persiguiendo else 1.45) * clamp(velocidad_lineal / 2.2, 0.4, 2.2)
	if moviendose:
		_fase_marcha += delta * freq * TAU
	
	# 1. Postura del torso a cuatro patas (pelvis baja, columna horizontal arqueada, cabeza erguida)
	var balanceo_pelvis: float = sin(_fase_marcha * 2.0) * 0.035 if moviendose else sin(_tiempo * 2.2) * 0.015
	var altura_pelvis: float = 0.56 + balanceo_pelvis
	
	_set_pose_rot_pos("pelvis", Vector3(0.0, altura_pelvis, -0.25), Vector3(deg_to_rad(58.0), sin(_fase_marcha) * 0.08, 0.0))
	_set_pose_rot("spine_lower", Vector3(deg_to_rad(18.0), sin(_fase_marcha + 0.5) * 0.06, 0.0))
	_set_pose_rot("spine_upper", Vector3(deg_to_rad(12.0), -sin(_fase_marcha) * 0.07, 0.0))
	
	# Cuello y cabeza compensan la inclinación del torso para mirar al frente (+Z en tu spec)
	var giro_cabeza: float = sin(_tiempo * 1.7) * 0.18 if not persiguiendo else sin(_tiempo * 9.0) * 0.06
	_set_pose_rot("neck", Vector3(deg_to_rad(-42.0), giro_cabeza * 0.5, 0.0))
	_set_pose_rot("head", Vector3(deg_to_rad(-36.0), giro_cabeza, sin(_tiempo * 3.1) * 0.05))
	
	# Mandíbula: ligeramente entreabierta al acechar, abierta de par en par al perseguir
	var objetivo_boca: float = 0.62 if persiguiendo else (0.16 + sin(_tiempo * 2.5) * 0.05)
	_boca_abierta = lerp(_boca_abierta, objetivo_boca, delta * 8.0)
	_set_pose_rot("jaw", Vector3(_boca_abierta, 0.0, 0.0))
	
	# 2. Cinemática Inversa (IK) para las 4 patas apoyadas en el suelo (Y = 0.02 en espacio local del monstruo)
	var largo_paso: float = 0.42 if persiguiendo else 0.30
	var alto_paso: float = 0.22 if persiguiendo else 0.14
	
	# Marcha diagonal cuadrúpeda:
	# Mano Izq (fase 0) + Pie Der (fase 0.2) | Mano Der (fase PI) + Pie Izq (fase PI + 0.2)
	var target_mano_l: Vector3 = _calcular_objetivo_pata(Vector3(0.38, 0.03, 0.58), _fase_marcha, largo_paso, alto_paso, moviendose)
	var target_mano_r: Vector3 = _calcular_objetivo_pata(Vector3(-0.38, 0.03, 0.58), _fase_marcha + PI, largo_paso, alto_paso, moviendose)
	var target_pie_l: Vector3  = _calcular_objetivo_pata(Vector3(0.28, 0.03, -0.42), _fase_marcha + PI + 0.3, largo_paso, alto_paso, moviendose)
	var target_pie_r: Vector3  = _calcular_objetivo_pata(Vector3(-0.28, 0.03, -0.42), _fase_marcha + 0.3, largo_paso, alto_paso, moviendose)
	
	# Resolvemos IK de 2 huesos (codos apuntan hacia atrás -Z, rodillas hacia adelante +Z)
	_resolver_ik_extremidad("upper_arm_L", "forearm_L", target_mano_l, Vector3(0.2, 0.3, -1.0), _len_upper_arm, _len_forearm)
	_resolver_ik_extremidad("upper_arm_R", "forearm_R", target_mano_r, Vector3(-0.2, 0.3, -1.0), _len_upper_arm, _len_forearm)
	_resolver_ik_extremidad("thigh_L", "shin_L", target_pie_l, Vector3(0.1, 0.3, 1.0), _len_thigh, _len_shin)
	_resolver_ik_extremidad("thigh_R", "shin_R", target_pie_r, Vector3(-0.1, 0.3, 1.0), _len_thigh, _len_shin)

func _calcular_objetivo_pata(base: Vector3, fase: float, largo: float, alto: float, moviendose: bool) -> Vector3:
	if not moviendose:
		return base
	var z_offset: float = sin(fase) * largo
	var y_lift: float = max(0.0, cos(fase)) * alto
	return Vector3(base.x, base.y + y_lift, base.z + z_offset)

# IK analítica de 2 huesos en espacio local del Skeleton3D
func _resolver_ik_extremidad(nombre_raiz: String, nombre_medio: String, objetivo_skel: Vector3, pole_dir: Vector3, len1: float, len2: float) -> void:
	var idx1: int = _bones.get(nombre_raiz, -1)
	var idx2: int = _bones.get(nombre_medio, -1)
	if idx1 == -1 or idx2 == -1:
		return
	
	var g_pose1: Transform3D = _skel.get_bone_global_pose(idx1)
	var origen: Vector3 = g_pose1.origin
	
	var vec_objetivo: Vector3 = objetivo_skel - origen
	var dist: float = clamp(vec_objetivo.length(), 0.08, (len1 + len2) * 0.98)
	var dir_objetivo: Vector3 = vec_objetivo.normalized()
	
	# Ley de cosenos para ángulo del hombro/cadera y del codo/rodilla
	var cos_a: float = clamp((len1 * len1 + dist * dist - len2 * len2) / (2.0 * len1 * dist), -1.0, 1.0)
	var ang_a: float = acos(cos_a)
	
	var cos_b: float = clamp((len1 * len1 + len2 * len2 - dist * dist) / (2.0 * len1 * len2), -1.0, 1.0)
	var ang_codo: float = PI - acos(cos_b)
	
	# Plano de flexión definido por el vector hacia el objetivo y el pole vector (codo/rodilla)
	var eje_lateral: Vector3 = dir_objetivo.cross(pole_dir.normalized())
	if eje_lateral.length_squared() < 0.0001:
		eje_lateral = Vector3.RIGHT
	else:
		eje_lateral = eje_lateral.normalized()
	
	# En tu BONES_SPEC los huesos apuntan aproximadamente hacia -Y en reposo
	var dir_hueso1: Vector3 = dir_objetivo.rotated(eje_lateral, ang_a)
	var rot1: Quaternion = Quaternion(Vector3.DOWN, dir_hueso1)
	
	# Aplicamos rotación global convertida a pose local del hueso raíz
	var padre1: int = _skel.get_bone_parent(idx1)
	var parent_basis: Basis = _skel.get_bone_global_pose(padre1).basis if padre1 != -1 else Basis.IDENTITY
	var escala1: Vector3 = _skel.get_bone_pose_scale(idx1)
	_skel.set_bone_pose_rotation(idx1, (parent_basis.inverse() * Basis(rot1)).get_rotation_quaternion())
	_skel.set_bone_pose_scale(idx1, escala1)
	
	# Flexión local del codo / rodilla
	var rest2: Transform3D = _rest_poses[idx2]
	var flex_sign: float = -1.0 if "arm" in nombre_raiz else 1.0
	var rot2: Quaternion = rest2.basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, ang_codo * flex_sign)
	_skel.set_bone_pose_rotation(idx2, rot2)

func _animar_jumpscare() -> void:
	# Pose de susto: cara erguida mirando directo al jugador y mandíbula desencajada temblando
	_set_pose_rot_pos("pelvis", Vector3(0.0, 0.95, 0.0), Vector3.ZERO)
	_set_pose_rot("spine_lower", Vector3(0.1, 0.0, 0.0))
	_set_pose_rot("spine_upper", Vector3(0.15, 0.0, 0.0))
	_set_pose_rot("neck", Vector3(-0.1, 0.0, sin(_tiempo * 35.0) * 0.08))
	_set_pose_rot("head", Vector3(-0.08, cos(_tiempo * 40.0) * 0.07, sin(_tiempo * 30.0) * 0.06))
	_set_pose_rot("jaw", Vector3(0.88 + sin(_tiempo * 45.0) * 0.08, 0.0, 0.0))

func _set_pose_rot(nombre: String, euler: Vector3) -> void:
	var idx: int = _bones.get(nombre, -1)
	if idx == -1:
		return
	var rest: Transform3D = _rest_poses[idx]
	var q: Quaternion = rest.basis.get_rotation_quaternion() * Quaternion.from_euler(euler)
	_skel.set_bone_pose_rotation(idx, q)

func _set_pose_rot_pos(nombre: String, offset_pos: Vector3, euler: Vector3) -> void:
	var idx: int = _bones.get(nombre, -1)
	if idx == -1:
		return
	var rest: Transform3D = _rest_poses[idx]
	_skel.set_bone_pose_position(idx, offset_pos)
	var q: Quaternion = rest.basis.get_rotation_quaternion() * Quaternion.from_euler(euler)
	_skel.set_bone_pose_rotation(idx, q)
