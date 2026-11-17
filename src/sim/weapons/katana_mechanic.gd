class_name KatanaMechanic
extends RefCounted
## LA VOIE DU SABRE — mécanique propre au katana.
##  - Zanshin (weapon_pips) : gagné en lisant l'adversaire, sert à annuler une recovery (A) ou à lancer Issen.
##  - Tranchant (weapon_gauge) : multiplie les dégâts LAME, baisse quand la lame est bloquée/parée.
##  - Posture Iai : gérée de façon générique par les coups "stance" (FighterLogic) ; ici les bonus.
## Toutes les valeurs sont dans data/weapons/katana.json > "mechanic".


static func is_katana(moves: MoveSet) -> bool:
	return moves.mechanic_type() == "katana"


static func gain_zanshin(f: FighterState, moves: MoveSet, n: int = 1) -> void:
	if not is_katana(moves):
		return
	var before := f.weapon_pips
	f.weapon_pips = clampi(f.weapon_pips + n, 0, int(moves.mech("zanshin_max", 3)))
	if f.weapon_pips > before and f.pending_fx == "":
		f.pending_fx = "zanshin_gain"


static func lose_edge(f: FighterState, moves: MoveSet, key: String) -> void:
	if is_katana(moves):
		f.weapon_gauge = maxi(f.weapon_gauge - int(moves.mech(key, 0)), 0)


## Multiplicateur de dégâts LAME selon le tranchant (et la charge de la posture, et Issen).
static func damage_mult(f: FighterState, moves: MoveSet, m: Dictionary) -> float:
	if not is_katana(moves) or m.get("button", "") != "blade":
		return 1.0
	var e := float(f.weapon_gauge) / 100.0
	var mult := lerpf(float(moves.mech("edge_min_mult", 0.7)), float(moves.mech("edge_max_mult", 1.15)), e)
	if m.get("stance", false) and f.charge_ticks > 0:
		var k := float(f.charge_ticks) / float(maxi(int(moves.mech("stance_max_ticks", 90)), 1))
		mult *= 1.0 + float(moves.mech("charge_max_bonus", 1.0)) * clampf(k, 0.0, 1.0)
	if f.issen:
		mult *= float(moves.mech("issen_damage_mult", 2.0))
	return mult


## A pendant un coup qui a touché ou été bloqué : on dépense du Zanshin pour annuler sa recovery.
static func try_cancel(f: FighterState, moves: MoveSet) -> bool:
	if not is_katana(moves) or f.action != FighterState.Action.ATTACK or f.issen:
		return false
	var m := moves.get_move(f.move_id)
	if m.is_empty() or f.hit_groups == 0 or f.move_tick <= int(m["startup"]):
		return false
	var cost := int(moves.mech("cancel_cost", 1))
	if f.weapon_pips < cost:
		return false
	f.weapon_pips -= cost
	FighterLogic.end_move(f)
	f.guard = -f.guard
	f.vel.x *= 0.3
	f.vel.z *= 0.3
	f.pending_fx = "zanshin_cancel"
	return true


## Au moment où l'on dégaine depuis la posture : Issen si le Zanshin est plein.
static func on_stance_release(f: FighterState, moves: MoveSet) -> void:
	if not is_katana(moves):
		return
	var cost := int(moves.mech("issen_cost", 3))
	if f.weapon_pips >= cost:
		f.weapon_pips -= cost
		f.issen = true
		f.pending_fx = "issen"
	else:
		f.pending_fx = "iai_draw"
