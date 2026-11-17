class_name WeaponAnim
extends RefCounted
## Animations placeholder de l'arme, calculées à partir de la frame data :
## la position "armée" est atteinte à la fin du startup, le geste se fait pendant
## l'active, puis retour à la garde pendant la recovery. Ainsi l'animation
## correspond TOUJOURS exactement aux ticks du fichier JSON.
##
## Une pose = [poignée (Vector3, repère caméra), direction de la lame (Vector3)].
## Repère caméra : x = droite, y = haut, -z = devant. Écrit pour la garde droite.

const POSES := {
	"rest": [Vector3(0.30, -0.36, -0.55), Vector3(-0.35, 0.75, -0.58)],

	"diag_windup": [Vector3(0.38, -0.02, -0.38), Vector3(0.35, 0.9, 0.3)],
	"diag_end": [Vector3(-0.28, -0.48, -0.55), Vector3(-0.65, -0.5, -0.6)],
	"diag_rev_end": [Vector3(0.38, -0.08, -0.5), Vector3(0.65, 0.6, -0.5)],

	"thrust_windup": [Vector3(0.26, -0.3, -0.22), Vector3(0.0, 0.05, -1.0)],
	"thrust_end": [Vector3(0.06, -0.22, -0.95), Vector3(0.0, 0.0, -1.0)],

	"horiz_windup": [Vector3(0.52, -0.22, -0.3), Vector3(1.0, 0.1, -0.15)],
	"horiz_end": [Vector3(-0.42, -0.26, -0.5), Vector3(-0.95, 0.0, -0.35)],

	"rising_windup": [Vector3(0.22, -0.62, -0.4), Vector3(0.2, -0.55, -0.8)],
	"rising_end": [Vector3(0.12, 0.1, -0.5), Vector3(0.1, 1.0, -0.3)],

	"down_windup": [Vector3(0.12, 0.16, -0.3), Vector3(0.0, 0.7, 0.7)],
	"down_end": [Vector3(0.05, -0.52, -0.62), Vector3(0.0, -0.4, -0.9)],

	"pommel_windup": [Vector3(0.22, -0.36, -0.32), Vector3(-0.3, 0.8, 0.5)],
	"pommel_end": [Vector3(0.05, -0.16, -0.82), Vector3(0.0, 0.6, 0.8)],

	"brace_windup": [Vector3(0.40, -0.48, -0.3), Vector3(0.15, 1.0, 0.1)],
	"brace_end": [Vector3(0.30, -0.5, -0.3), Vector3(0.2, 1.0, 0.0)],

	"sheathed": [Vector3(-0.22, -0.58, -0.3), Vector3(0.25, -0.1, 1.0)],
	"iai_end": [Vector3(0.48, -0.3, -0.5), Vector3(0.9, 0.1, -0.35)],

	"flick_windup": [Vector3(0.3, -0.28, -0.5), Vector3(0.0, 1.0, -0.2)],
	"flick_end": [Vector3(0.38, -0.52, -0.6), Vector3(0.7, -0.6, -0.4)],
}

## Type d'anim -> poses clés : [armé (fin du startup), ..., fin de l'active]
const ANIMS := {
	"none": [],
	"diag": ["diag_windup", "diag_end"],
	"diag_rev": ["diag_end", "diag_rev_end"],
	"thrust": ["thrust_windup", "thrust_end"],
	"horizontal": ["horiz_windup", "horiz_end"],
	"rising": ["rising_windup", "rising_end"],
	"down": ["down_windup", "down_end"],
	"down_up": ["down_windup", "down_end", "rising_end"],
	"pommel": ["pommel_windup", "pommel_end"],
	"brace": ["brace_windup", "brace_end"],
	"iai": ["sheathed", "iai_end"],
	"feint": ["sheathed", "sheathed"],
	"sheathe": ["sheathed", "sheathed"],
	"flick": ["flick_windup", "flick_end"],
}


## t = tick du coup (avec la fraction d'interpolation). side = +1 garde droite, -1 gauche.
static func pose_for_move(m: Dictionary, t: float, side: float) -> Array:
	var keys: Array = ANIMS.get(m.get("anim", "none"), [])
	var startup := float(m["startup"])
	var active := float(m["active"])
	var total := float(m["total"])
	var rest: Array = POSES["rest"]
	if keys.is_empty():
		return mirror(rest, side)

	# Liste de [tick, pose]
	var timeline: Array = [[0.0, rest]]
	var n := keys.size()
	for k in n:
		var kt := startup + (active * float(k) / float(maxi(n - 1, 1)) if n > 1 else 0.0)
		timeline.append([kt, POSES[keys[k]]])
	timeline.append([total, rest])

	for k in range(timeline.size() - 1):
		var t0: float = timeline[k][0]
		var t1: float = timeline[k + 1][0]
		if t <= t1 or k == timeline.size() - 2:
			var u := 0.0 if t1 <= t0 else clampf((t - t0) / (t1 - t0), 0.0, 1.0)
			# startup : on arme (ease-out), active : geste sec, recovery : retour doux
			if k == 0:
				u = 1.0 - pow(1.0 - u, 2.0)
			elif k == timeline.size() - 2:
				u = smoothstep(0.0, 1.0, u)
			return mirror(lerp_pose(timeline[k][1], timeline[k + 1][1], u), side)
	return mirror(rest, side)


static func lerp_pose(a: Array, b: Array, u: float) -> Array:
	var grip: Vector3 = (a[0] as Vector3).lerp(b[0], u)
	var dir: Vector3 = (a[1] as Vector3).normalized().lerp((b[1] as Vector3).normalized(), u)
	if dir.length_squared() < 0.0001:
		dir = Vector3.UP
	return [grip, dir.normalized()]


static func mirror(p: Array, side: float) -> Array:
	var g: Vector3 = p[0]
	var d: Vector3 = p[1]
	return [Vector3(g.x * side, g.y, g.z), Vector3(d.x * side, d.y, d.z).normalized()]


## Base orientée pour que l'axe +Y de l'arme suive la direction de la lame.
static func basis_from_dir(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var ref := Vector3(0, 0, -1)
	if absf(y.dot(ref)) > 0.95:
		ref = Vector3(1, 0, 0)
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)
