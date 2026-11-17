class_name MotionParser
extends RefCounted
## MÉMOIRE DE DIRECTIONS.
## Le jeu retient les directions tapées (seulement ← → ↓ ↙ ↘ ; avancer, sauter et s'accroupir ne comptent pas).
## Au clic, les 3 dernières directions DIFFÉRENTES forment la "manip" du coup (ex : ↓↘→ = 236).
## La mémoire n'est JAMAIS effacée (ni par le temps, ni quand un coup est lancé) : seules de nouvelles
## directions la font évoluer. Re-cliquer relance donc le même coup.
##
## Notation numpad (garde droite) :  1 = ↙   2 = ↓   3 = ↘   4 = ←   6 = →
## En garde gauche, tout est inversé en miroir (4 <-> 6, 1 <-> 3).

const MAX_HISTORY := 8
const ARROWS := {1: "↙", 2: "↓", 3: "↘", 4: "←", 6: "→", 5: "·"}


## Direction numpad physique à partir des touches tenues (5 = aucune).
static func dir_from_buttons(held: int) -> int:
	var l := (held & InputFrame.LEFT) != 0
	var r := (held & InputFrame.RIGHT) != 0
	var b := (held & InputFrame.BACK) != 0
	if l and r:
		l = false
		r = false
	if b:
		return 1 if l else (3 if r else 2)
	if l:
		return 4
	if r:
		return 6
	return 5


static func mirror_dir(d: int) -> int:
	match d:
		1: return 3
		3: return 1
		4: return 6
		6: return 4
	return d


static func mirror_notation(s: String) -> String:
	var out := ""
	for c in s:
		out += str(mirror_dir(int(c)))
	return out


## Notation -> flèches (ex : "236" -> "↓↘→").
static func arrows(notation: String) -> String:
	var out := ""
	for c in notation:
		out += str(ARROWS.get(int(c), c))
	return out


## Mémorise la direction du tick si elle change (les "5" = relâché ne sont pas gardés).
static func record(f: FighterState, held: int) -> void:
	var d := dir_from_buttons(held)
	if d == f.last_dir:
		return
	f.last_dir = d
	if d == 5:
		return
	f.dir_history.append([d, f.local_tick])
	if f.dir_history.size() > MAX_HISTORY:
		f.dir_history.pop_front()


## Les 3 dernières directions différentes (de la plus ancienne à la plus récente), en physique.
static func memory(history: Array) -> Array[int]:
	var out: Array[int] = []
	for i in range(history.size() - 1, -1, -1):
		var d: int = int(history[i][0])
		if not out.has(d):
			out.push_front(d)
			if out.size() == 3:
				break
	return out


static func notation_of(mem: Array[int], guard: int) -> String:
	var s := ""
	for d in mem:
		s += str(mirror_dir(d) if guard == FighterState.GUARD_LEFT else d)
	return s


## Que fait un clic maintenant ? Renvoie {"kind": "dash"/"move", "notation": "426"..., "trail"}.
## Dash : la manip du dash, éventuellement suivie (moins de grace ticks) d'une direction = sens du dash
## ("trail" = vrai). Sans direction ajoutée, le dash part tout droit devant.
static func resolve_click(f: FighterState, dash_triple: String, grace: int) -> Dictionary:
	var mem := memory(f.dir_history)
	var nota := notation_of(mem, f.guard) if mem.size() == 3 else "5"
	if nota == dash_triple:
		return {"kind": "dash", "notation": nota, "trail": false}
	var n := f.dir_history.size()
	if n >= 2:
		var last_tick := int(f.dir_history[n - 1][1])
		if f.local_tick - last_tick <= grace:
			var prev := memory(f.dir_history.slice(0, n - 1))
			if prev.size() == 3 and notation_of(prev, f.guard) == dash_triple:
				return {"kind": "dash", "notation": dash_triple, "trail": true}
	return {"kind": "move", "notation": nota, "trail": false}
