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

	# Garde : lame en travers devant soi. Sonné : arme repoussée sur le côté.
	"block": [Vector3(0.08, -0.2, -0.45), Vector3(-1.0, 0.3, -0.15)],
	"block_low": [Vector3(0.1, -0.42, -0.45), Vector3(-1.0, -0.05, -0.2)],
	"staggered": [Vector3(0.5, -0.08, -0.25), Vector3(0.6, 0.7, 0.4)],

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


## Mouvement de caméra par type de coup (en degrés / mètres) : le "corps" suit le geste.
## roll = pencher la tête, pitch = haut/bas, yaw = gauche/droite, push = avancer la caméra.
const CAM := {
	"diag": {"roll": 7.0, "pitch": -3.0, "yaw": -3.0, "push": 0.06},
	"diag_rev": {"roll": -6.0, "pitch": 2.0, "yaw": 3.0, "push": 0.06},
	"thrust": {"roll": 0.0, "pitch": -1.5, "yaw": 0.0, "push": 0.22},
	"horizontal": {"roll": 4.0, "pitch": 0.0, "yaw": -8.0, "push": 0.08},
	"rising": {"roll": -3.0, "pitch": 6.0, "yaw": 0.0, "push": 0.05},
	"down": {"roll": 0.0, "pitch": -9.0, "yaw": 0.0, "push": 0.12},
	"down_up": {"roll": 2.0, "pitch": -6.0, "yaw": 0.0, "push": 0.08},
	"pommel": {"roll": 2.0, "pitch": -2.0, "yaw": 0.0, "push": 0.16},
	"brace": {"roll": -6.0, "pitch": -2.0, "yaw": 4.0, "push": 0.2},
	"iai": {"roll": 6.0, "pitch": 0.0, "yaw": -10.0, "push": 0.14},
	"flick": {"roll": -4.0, "pitch": -2.0, "yaw": 0.0, "push": 0.0},
}

const OVERSHOOT := 0.3        ## le geste continue 30 % plus loin après l'impact (follow-through)
const WINDUP_ARRIVE := 0.75   ## la pose armée est atteinte à 75 % du startup, puis tenue (lisible !)

enum Ease { OUT, LINEAR, IN, OUT_CUBIC, SMOOTH }


## t = tick du coup (avec la fraction d'interpolation). side = +1 garde droite, -1 gauche.
static func pose_for_move(m: Dictionary, t: float, side: float) -> Array:
	var keys: Array = ANIMS.get(m.get("anim", "none"), [])
	var startup := float(m["startup"])
	var active := float(m["active"])
	var total := float(m["total"])
	var rest: Array = POSES["rest"]
	if keys.is_empty():
		return mirror(rest, side)

	# [tick, pose, easing du segment qui ARRIVE sur cette clé]
	var timeline: Array = [[0.0, rest, Ease.LINEAR]]
	timeline.append([startup * WINDUP_ARRIVE, POSES[keys[0]], Ease.OUT])   # on arme
	timeline.append([startup, POSES[keys[0]], Ease.LINEAR])                 # on tient (anticipation)
	var n := keys.size()
	for k in range(1, n):
		var kt := startup + active * float(k) / float(n - 1)
		timeline.append([kt, POSES[keys[k]], Ease.IN])                      # geste qui accélère vers l'impact
	var last: Array = POSES[keys[n - 1]]
	var before: Array = POSES[keys[maxi(n - 2, 0)]]
	var recovery := total - startup - active
	var follow_t := startup + active + minf(5.0, recovery * 0.35)
	timeline.append([follow_t, overshoot(before, last, OVERSHOOT), Ease.OUT_CUBIC])  # follow-through
	timeline.append([total, rest, Ease.SMOOTH])                              # retour en garde

	for k in range(timeline.size() - 1):
		var t0: float = timeline[k][0]
		var t1: float = timeline[k + 1][0]
		if t <= t1 or k == timeline.size() - 2:
			var u := 1.0 if t1 <= t0 else clampf((t - t0) / (t1 - t0), 0.0, 1.0)
			u = ease_value(u, timeline[k + 1][2])
			return mirror(lerp_pose(timeline[k][1], timeline[k + 1][1], u), side)
	return mirror(rest, side)


static func ease_value(u: float, kind: int) -> float:
	match kind:
		Ease.OUT:
			return 1.0 - (1.0 - u) * (1.0 - u)
		Ease.IN:
			return u * u
		Ease.OUT_CUBIC:
			return 1.0 - pow(1.0 - u, 3.0)
		Ease.SMOOTH:
			return smoothstep(0.0, 1.0, u)
	return u


static func overshoot(before: Array, last: Array, amount: float) -> Array:
	var g: Vector3 = last[0]
	var gb: Vector3 = before[0]
	var d: Vector3 = (last[1] as Vector3).normalized()
	var db: Vector3 = (before[1] as Vector3).normalized()
	var nd := d + (d - db) * amount
	return [g + (g - gb) * amount, nd.normalized() if nd.length() > 0.01 else d]


## Intensité du mouvement de caméra : léger recul pendant le startup (anticipation),
## pic juste après l'impact, retour pendant la recovery.
static func cam_curve(m: Dictionary, t: float) -> float:
	var s := float(m["startup"])
	var a := float(m["active"])
	var total := float(m["total"])
	if t <= s:
		return -0.35 * smoothstep(0.0, 1.0, t / maxf(s, 1.0))
	if t <= s + a + 2.0:
		var u := clampf((t - s) / maxf(a + 2.0, 1.0), 0.0, 1.0)
		return lerpf(-0.35, 1.0, 1.0 - pow(1.0 - u, 3.0))
	var r := clampf((t - s - a - 2.0) / maxf(total - s - a - 2.0, 1.0), 0.0, 1.0)
	return 1.0 - smoothstep(0.0, 1.0, r)


## Pose hors attaque selon l'état (garde, sonné, repos).
static func state_pose(f: FighterState) -> Array:
	var side := float(f.guard)
	if f.action == FighterState.Action.BLOCK or f.action == FighterState.Action.BLOCKSTUN:
		return mirror(POSES["block_low"] if f.is_crouching() else POSES["block"], side)
	if f.action == FighterState.Action.HITSTUN or f.action == FighterState.Action.PARRIED:
		return mirror(POSES["staggered"], side)
	return mirror(POSES["rest"], side)


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
