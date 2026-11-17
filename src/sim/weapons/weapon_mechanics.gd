class_name WeaponMechanics
extends RefCounted
## Point d'entrée des mécaniques propres à chaque arme (réglages : data/weapons/<arme>.json > "mechanic").
##   katana   : LA VOIE DU SABRE (Zanshin, Tranchant, posture Iai)        -> KatanaMechanic
##   tanto    : DANSE DES LAMES (bonus de jonglage, tantō lancé = coups affaiblis)
##   naginata : MA-AI (frapper de la POINTE paie, le corps à corps est faible)
##   kanabo   : IKARI (la rage monte quand on encaisse ; pleine = armure + dégâts)


static func type_of(moves: MoveSet) -> String:
	return moves.mechanic_type()


## Valeurs de départ (au début de chaque round).
static func init(f: FighterState, moves: MoveSet) -> void:
	f.weapon_pips = 0
	f.weapon_gauge = 100 if type_of(moves) == "katana" else 0


static func gain_pips(f: FighterState, moves: MoveSet, n: int) -> void:
	match type_of(moves):
		"katana":
			KatanaMechanic.gain_zanshin(f, moves, n)
		_:
			var before := f.weapon_pips
			f.weapon_pips = clampi(f.weapon_pips + n, 0, int(moves.mech("pips_max", 3)))
			if f.weapon_pips > before:
				f.pending_fx = "pips_gain"


## Rage du kanabō pleine ?
static func fury_ready(f: FighterState, moves: MoveSet) -> bool:
	return type_of(moves) == "kanabo" and f.weapon_gauge >= int(moves.mech("gauge_max", 100))


## Armure "gratuite" : kanabō en rage pendant le startup d'un coup LAME.
static func fury_armor(f: FighterState, moves: MoveSet) -> bool:
	if not fury_ready(f, moves) or f.action != FighterState.Action.ATTACK:
		return false
	var m := moves.get_move(f.move_id)
	return not m.is_empty() and m["button"] == "blade" and f.move_tick <= int(m["startup"])


## Multiplicateur de dégâts. dist = distance horizontale entre les deux combattants.
static func damage_mult(att: FighterState, moves: MoveSet, m: Dictionary, dist: float) -> float:
	var blade: bool = m.get("button", "") == "blade"
	match type_of(moves):
		"katana":
			return KatanaMechanic.damage_mult(att, moves, m)
		"tanto":
			var mult := 1.0
			if blade and att.weapon_lost > 0:
				mult *= float(moves.mech("lost_mult", 0.6))
			if blade and att.weapon_pips > 0:
				mult *= 1.0 + float(moves.mech("pip_bonus", 0.3)) * att.weapon_pips
			return mult
		"naginata":
			if not blade:
				return 1.0
			if dist >= float(moves.mech("tip_distance", 2.3)):
				return float(moves.mech("tip_mult", 1.25))
			if dist <= float(moves.mech("close_distance", 1.3)):
				return float(moves.mech("close_mult", 0.7))
			return 1.0
		"kanabo":
			return float(moves.mech("fury_mult", 1.3)) if (blade and fury_ready(att, moves)) else 1.0
	return 1.0


## Bonus de hitstun (pointe de la naginata).
static func hitstun_bonus(moves: MoveSet, m: Dictionary, dist: float) -> int:
	if type_of(moves) == "naginata" and m.get("button", "") == "blade" and dist >= float(moves.mech("tip_distance", 2.3)):
		return int(moves.mech("tip_hitstun", 4))
	return 0


## Après un coup qui touche : on consomme ce qui doit l'être. Renvoie un mot-clé d'effet ("" sinon).
static func on_hit(att: FighterState, moves: MoveSet, m: Dictionary, dist: float) -> String:
	var blade: bool = m.get("button", "") == "blade"
	match type_of(moves):
		"tanto":
			if blade and att.weapon_pips > 0:
				att.weapon_pips = 0
				return "juggle_release"
		"naginata":
			if blade and dist >= float(moves.mech("tip_distance", 2.3)):
				return "tipper"
		"kanabo":
			if blade and fury_ready(att, moves):
				att.weapon_gauge = 0
				return "fury_release"
	return ""


static func on_damage_taken(def: FighterState, moves: MoveSet, dmg: int) -> void:
	if type_of(moves) == "kanabo":
		def.weapon_gauge = mini(def.weapon_gauge + roundi(dmg * float(moves.mech("gauge_per_damage", 0.18))), int(moves.mech("gauge_max", 100)))


static func on_block(def: FighterState, moves: MoveSet) -> void:
	if type_of(moves) == "kanabo":
		def.weapon_gauge = mini(def.weapon_gauge + int(moves.mech("gauge_per_block", 8)), int(moves.mech("gauge_max", 100)))
