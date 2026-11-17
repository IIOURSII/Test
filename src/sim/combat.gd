class_name Combat
extends RefCounted
## Géométrie du combat : hurtbox (corps), hitbox (coups), collisions capsule-capsule.
## Tout est calculé à la main (pas de moteur physique) pour rester déterministe.


## Hurtbox = capsule verticale du corps. Renvoie [a, b, rayon].
static func hurtbox(f: FighterState, cfg: Dictionary) -> Array:
	var fc: Dictionary = cfg["fighter"]
	var r: float = fc["radius"]
	var t := float(f.crouch) / float(FighterLogic.CROUCH_TICKS)
	var h := lerpf(float(fc["height"]), float(fc["crouch_height"]), t)
	return [f.pos + Vector3(0, r, 0), f.pos + Vector3(0, h - r, 0), r]


## Repère d'attaque [avant, droite], avec le magnétisme vers la cible.
static func attack_frame(att: FighterState, target: FighterState, cfg: Dictionary) -> Array:
	var fwd := att.forward()
	var aa: Dictionary = cfg.get("aim_assist", {})
	if target != null and not aa.is_empty():
		var d := target.pos - att.pos
		d.y = 0.0
		var dist := d.length()
		if dist > 0.01 and dist <= float(aa.get("range", 0.0)):
			var dn := d / dist
			if rad_to_deg(fwd.angle_to(dn)) <= float(aa.get("angle_deg", 0.0)):
				fwd = dn
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	return [fwd, right]


## Hitbox dans le monde. local = [côté, hauteur, avant] ; côté inversé selon la garde.
static func hitbox_world(att: FighterState, hb: Dictionary, frame: Array) -> Array:
	var fwd: Vector3 = frame[0]
	var right: Vector3 = frame[1]
	var la: Vector3 = hb["a"]
	var lb: Vector3 = hb["b"]
	var g := float(att.guard)
	var a := att.pos + right * (la.x * g) + Vector3(0, la.y, 0) + fwd * la.z
	var b := att.pos + right * (lb.x * g) + Vector3(0, lb.y, 0) + fwd * lb.z
	return [a, b, float(hb["radius"])]


static func capsules_overlap(c1: Array, c2: Array) -> bool:
	var r: float = float(c1[2]) + float(c2[2])
	return segment_distance_sq(c1[0], c1[1], c2[0], c2[1]) <= r * r


## Distance² minimale entre deux segments [p1,q1] et [p2,q2] (méthode classique d'Ericson).
static func segment_distance_sq(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3) -> float:
	var d1 := q1 - p1
	var d2 := q2 - p2
	var r := p1 - p2
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	var s := 0.0
	var t := 0.0
	const EPS := 1e-8
	if a <= EPS and e <= EPS:
		return r.dot(r)
	if a <= EPS:
		t = clampf(f / e, 0.0, 1.0)
	else:
		var c := d1.dot(r)
		if e <= EPS:
			s = clampf(-c / a, 0.0, 1.0)
		else:
			var b := d1.dot(d2)
			var denom := a * e - b * b
			if denom != 0.0:
				s = clampf((b * f - c * e) / denom, 0.0, 1.0)
			t = (b * s + f) / e
			if t < 0.0:
				t = 0.0
				s = clampf(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((b - c) / a, 0.0, 1.0)
	var c1 := p1 + d1 * s
	var c2 := p2 + d2 * t
	return (c1 - c2).length_squared()
