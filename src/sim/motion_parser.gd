class_name MotionParser
extends RefCounted
## Lit les manips type jeu de combat (notation numpad) dans l'historique des directions.
##
##   7 8 9        Seules comptent : 4 = gauche, 6 = droite, 2 = reculer,
##   4 5 6        1 = reculer+gauche, 3 = reculer+droite, 5 = rien.
##   1 2 3        Avancer, sauter et s'accroupir sont ignorés.
##
## L'historique stocke les directions PHYSIQUES. En garde gauche on inverse
## (4<->6, 1<->3) avant de chercher : les coups sont écrits pour la garde droite.

## Ordre de priorité si plusieurs manips correspondent.
const MOTIONS := ["623", "236", "214", "22", "44", "66"]
const MAX_HISTORY := 24


## Direction numpad physique à partir des touches tenues.
static func dir_from_buttons(held: int) -> int:
	if held & InputFrame.DASH:
		return 5  # les directions tapées pendant un dash ne comptent pas
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


## Ajoute la direction du tick à l'historique (seulement quand elle change).
static func record(f: FighterState, held: int) -> void:
	var d := dir_from_buttons(held)
	if d == f.last_dir:
		return
	f.last_dir = d
	f.dir_history.append([d, f.local_tick])
	if f.dir_history.size() > MAX_HISTORY:
		f.dir_history.pop_front()


## Renvoie la notation reconnue ("236", "6", "5"...) au moment du clic.
static func resolve(f: FighterState, window: int) -> String:
	var now := f.local_tick
	var guard_left := f.guard == FighterState.GUARD_LEFT
	# On garde les entrées encore "vivantes" dans la fenêtre.
	var dirs: Array[int] = []
	var n := f.dir_history.size()
	for i in n:
		var end_tick: int = now if i == n - 1 else int(f.dir_history[i + 1][1])
		if end_tick < now - window:
			continue
		var d: int = int(f.dir_history[i][0])
		dirs.append(mirror_dir(d) if guard_left else d)

	for m in MOTIONS:
		if _match(m, dirs):
			return m

	var held := f.last_dir
	if guard_left:
		held = mirror_dir(held)
	if held == 1 or held == 2 or held == 3:
		return "2"
	if held == 4:
		return "4"
	if held == 6:
		return "6"
	return "5"


## Cherche la séquence dans l'ordre (en partant de la plus récente).
static func _match(seq: String, dirs: Array[int]) -> bool:
	var idx := seq.length() - 1
	for k in range(dirs.size() - 1, -1, -1):
		if dirs[k] == int(seq[idx]):
			idx -= 1
			if idx < 0:
				return true
	return false
