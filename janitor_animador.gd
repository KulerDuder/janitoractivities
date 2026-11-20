class_name JanitorAnimador
extends RefCounted

var _skel: Skeleton3D
var _idx: Dictionary = {}
var _rest_poses: Dictionary = {}
var _tiempo: float = 0.0

const NOMBRES_HUESOS: Array[String] = [
	"root", "pelvis", "spine_lower", "spine_upper", "neck", "head",
	"keyring",
	"shoulder_L", "upper_arm_L", "forearm_L", "hand_L",
	"shoulder_R", "upper_arm_R", "forearm_R", "hand_R",
	"thigh_L", "shin_L", "thigh_R", "shin_R"
]

func _init(skeleton: Skeleton3D) -> void:
	_skel = skeleton
	if not _skel:
		return
	for nombre: String in NOMBRES_HUESOS:
		var id: int = _skel.find_bone(nombre)
		_idx[nombre] = id
		if id != -1:
			_rest_poses[nombre] = _skel.get_bone_rest(id)

func actualizar(delta: float, velocidad_horizontal: float, en_suelo: bool) -> void:
	if not _skel or not is_instance_valid(_skel):
		return
	
	var caminando: bool = abs(velocidad_horizontal) > 0.15
	var factor_vel: float = clamp(abs(velocidad_horizontal) / 3.8, 0.0, 1.3)
	
	if caminando:
		_tiempo += delta * (7.2 * max(factor_vel, 0.6))
	else:
		_tiempo += delta * 2.1
	
	# Reiniciamos a pose de reposo antes de aplicar rotaciones/desplazamientos locales
	for nombre: String in _rest_poses.keys():
		var id: int = _idx[nombre]
		_skel.set_bone_pose_position(id, _rest_poses[nombre].origin)
		_skel.set_bone_pose_rotation(id, _rest_poses[nombre].basis.get_rotation_quaternion())
	
	if not en_suelo:
		# Pose ligera en el aire si da un pequeño salto entre nubes
		_rotar_hueso("thigh_L", Vector3(0.35, 0.0, 0.0))
		_rotar_hueso("shin_L", Vector3(-0.55, 0.0, 0.0))
		_rotar_hueso("thigh_R", Vector3(-0.25, 0.0, 0.0))
		_rotar_hueso("shin_R", Vector3(-0.35, 0.0, 0.0))
		_rotar_hueso("upper_arm_L", Vector3(-0.3, 0.0, 0.25))
		_rotar_hueso("upper_arm_R", Vector3(-0.3, 0.0, -0.25))
		_rotar_hueso("keyring", Vector3(0.45, 0.0, 0.15))
		return
	
	if caminando:
		var s: float = sin(_tiempo)
		var c: float = cos(_tiempo)
		var rebote: float = abs(s) * 0.045 * factor_vel
		
		# Cadera con ligero rebote vertical y balanceo
		_desplazar_hueso("pelvis", Vector3(0.0, -rebote, 0.0))
		_rotar_hueso("pelvis", Vector3(0.0, s * 0.08 * factor_vel, c * 0.04 * factor_vel))
		
		# Torso y cabeza compensando el paso
		_rotar_hueso("spine_lower", Vector3(0.05 * factor_vel, -s * 0.06 * factor_vel, 0.0))
		_rotar_hueso("spine_upper", Vector3(0.06 * factor_vel, -s * 0.08 * factor_vel, 0.0))
		_rotar_hueso("neck", Vector3(-0.04 * factor_vel, 0.0, 0.0))
		_rotar_hueso("head", Vector3(sin(_tiempo * 2.0) * 0.03, s * 0.04, 0.0))
		
		# Pierna izquierda
		var muslo_l: float = s * 0.62 * factor_vel
		var rodilla_l: float = -max(0.0, -c) * 0.85 * factor_vel - 0.08
		_rotar_hueso("thigh_L", Vector3(muslo_l, 0.0, 0.0))
		_rotar_hueso("shin_L", Vector3(rodilla_l, 0.0, 0.0))
		
		# Pierna derecha (en oposición de fase)
		var muslo_r: float = -s * 0.62 * factor_vel
		var rodilla_r: float = -max(0.0, c) * 0.85 * factor_vel - 0.08
		_rotar_hueso("thigh_R", Vector3(muslo_r, 0.0, 0.0))
		_rotar_hueso("shin_R", Vector3(rodilla_r, 0.0, 0.0))
		
		# Brazos cruzados respecto a las piernas + flexión natural de codos
		_rotar_hueso("upper_arm_L", Vector3(-s * 0.48 * factor_vel, 0.0, 0.08))
		_rotar_hueso("forearm_L", Vector3(0.22 + max(0.0, -s) * 0.25 * factor_vel, 0.0, 0.0))
		
		_rotar_hueso("upper_arm_R", Vector3(s * 0.48 * factor_vel, 0.0, -0.08))
		_rotar_hueso("forearm_R", Vector3(0.22 + max(0.0, s) * 0.25 * factor_vel, 0.0, 0.0))
		
		# Llavero colgante del cinturón rebotando con inercia
		_rotar_hueso("keyring", Vector3(-c * 0.38 * factor_vel - 0.12, 0.0, sin(_tiempo * 2.0) * 0.18 * factor_vel))
	else:
		# Respiración tranquila en reposo
		var resp: float = sin(_tiempo)
		_desplazar_hueso("pelvis", Vector3(0.0, resp * 0.012, 0.0))
		_rotar_hueso("spine_upper", Vector3(resp * 0.025, 0.0, 0.0))
		_rotar_hueso("head", Vector3(-resp * 0.02, sin(_tiempo * 0.5) * 0.04, 0.0))
		_rotar_hueso("upper_arm_L", Vector3(0.04, 0.0, 0.06 + resp * 0.015))
		_rotar_hueso("forearm_L", Vector3(0.14, 0.0, 0.0))
		_rotar_hueso("upper_arm_R", Vector3(0.04, 0.0, -0.06 - resp * 0.015))
		_rotar_hueso("forearm_R", Vector3(0.14, 0.0, 0.0))
		_rotar_hueso("keyring", Vector3(sin(_tiempo * 1.3) * 0.05, 0.0, cos(_tiempo * 1.1) * 0.04))

func _rotar_hueso(nombre: String, euler_rad: Vector3) -> void:
	if not _rest_poses.has(nombre):
		return
	var id: int = _idx[nombre]
	var q_rest: Quaternion = _rest_poses[nombre].basis.get_rotation_quaternion()
	var q_extra := Quaternion.from_euler(euler_rad)
	_skel.set_bone_pose_rotation(id, q_rest * q_extra)

func _desplazar_hueso(nombre: String, offset: Vector3) -> void:
	if not _rest_poses.has(nombre):
		return
	var id: int = _idx[nombre]
	_skel.set_bone_pose_position(id, _rest_poses[nombre].origin + offset)
