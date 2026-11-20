class_name ZeusAnimador
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

func actualizar(delta: float) -> void:
	if not _skel or not is_instance_valid(_skel):
		return
	
	_tiempo += delta * 2.2
	
	for nombre: String in _rest_poses.keys():
		var id: int = _idx[nombre]
		_skel.set_bone_pose_position(id, _rest_poses[nombre].origin)
		_skel.set_bone_pose_rotation(id, _rest_poses[nombre].basis.get_rotation_quaternion())
	
	var s: float = sin(_tiempo)
	var c: float = cos(_tiempo)
	var s_lento: float = sin(_tiempo * 0.65)
	
	# Levitación suave de la cadera y el torso erguido
	_desplazar_hueso("pelvis", Vector3(0.0, s * 0.045, 0.0))
	_rotar_hueso("pelvis", Vector3(-0.04 + c * 0.03, s_lento * 0.05, c * 0.025))
	
	_rotar_hueso("spine_lower", Vector3(-0.03 + s * 0.025, 0.0, 0.0))
	_rotar_hueso("spine_upper", Vector3(-0.04 + s * 0.035, -s_lento * 0.04, 0.0))
	_rotar_hueso("neck", Vector3(0.03 - s * 0.02, 0.0, 0.0))
	_rotar_hueso("head", Vector3(0.04 + c * 0.03, s_lento * 0.06, sin(_tiempo * 0.8) * 0.025))
	
	# Brazos abiertos flotando con onda desfasada
	_rotar_hueso("shoulder_L", Vector3(0.0, 0.0, 0.08 + s * 0.04))
	_rotar_hueso("upper_arm_L", Vector3(-0.14 + c * 0.08, 0.0, 0.34 + s * 0.11))
	_rotar_hueso("forearm_L", Vector3(0.28 + sin(_tiempo - 0.6) * 0.12, 0.0, 0.08))
	_rotar_hueso("hand_L", Vector3(sin(_tiempo - 1.1) * 0.14, 0.0, 0.06))
	
	_rotar_hueso("shoulder_R", Vector3(0.0, 0.0, -0.08 - s * 0.04))
	_rotar_hueso("upper_arm_R", Vector3(-0.14 - c * 0.08, 0.0, -0.34 - s * 0.11))
	_rotar_hueso("forearm_R", Vector3(0.28 + cos(_tiempo - 0.6) * 0.12, 0.0, -0.08))
	_rotar_hueso("hand_R", Vector3(cos(_tiempo - 1.1) * 0.14, 0.0, -0.06))
	
	# Piernas suspendidas en el aire
	_rotar_hueso("thigh_L", Vector3(0.16 + c * 0.08, 0.0, 0.05))
	_rotar_hueso("shin_L", Vector3(-0.24 + sin(_tiempo - 0.5) * 0.10, 0.0, 0.0))
	
	_rotar_hueso("thigh_R", Vector3(0.36 - c * 0.09, 0.0, -0.05))
	_rotar_hueso("shin_R", Vector3(-0.52 + cos(_tiempo - 0.5) * 0.12, 0.0, 0.0))
	
	_rotar_hueso("keyring", Vector3(c * 0.08, 0.0, s * 0.06))

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
