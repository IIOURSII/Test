class_name DummyController
extends RefCounted
## Mannequin d'entraînement, avec plusieurs comportements (F2) comme le mode training
## des jeux de combat. Il produit des InputFrame exactement comme un joueur.

enum Mode { STAND, BLOCK, CROUCH_BLOCK, RANDOM_BLOCK, PARRY, ATTACK, BURST }
const NAMES := [
	"Immobile",
	"Garde debout",
	"Garde accroupie",
	"Garde aléatoire (debout/accroupi)",
	"Parry parfait",
	"Attaque (Kesa-giri en boucle)",
	"Burst dès le 2e coup encaissé",
]

var mode: int = Mode.STAND
var _t: int = 0
var _random_bits: int = InputFrame.PARRY
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 42


func cycle() -> void:
	mode = (mode + 1) % NAMES.size()


func mode_name() -> String:
	return NAMES[mode]


func poll(world: SimWorld, self_index: int, target_index: int) -> InputFrame:
	_t += 1
	var me := world.fighters[self_index]
	var target := world.fighters[target_index]
	var d := target.pos - me.pos
	var yaw := me.yaw
	if Vector2(d.x, d.z).length_squared() > 0.0001:
		yaw = InputFrame.yaw_to_int(atan2(-d.x, -d.z))

	var b := 0
	# En bind (lames croisées), le mannequin martèle à rythme fixe : à toi d'aller plus vite.
	if me.action == FighterState.Action.BIND:
		return InputFrame.new(InputFrame.BLADE if _t % 9 < 4 else 0, yaw, 0)
	match mode:
		Mode.BLOCK:
			b = InputFrame.PARRY
		Mode.CROUCH_BLOCK:
			b = InputFrame.PARRY | InputFrame.CROUCH
		Mode.RANDOM_BLOCK:
			if _t % 40 == 0:
				_random_bits = InputFrame.PARRY | (InputFrame.CROUCH if _rng.randf() < 0.5 else 0)
			b = _random_bits
		Mode.PARRY:
			# Appuie sur E 3 ticks avant que la hitbox adverse ne sorte.
			if target.action == FighterState.Action.ATTACK:
				var m := world.movesets[target_index].get_move(target.move_id)
				for hb in m.get("hitboxes", []):
					var tk: Vector2i = hb["ticks"]
					if target.move_tick >= tk.x - 3 and target.move_tick <= tk.x:
						b = InputFrame.PARRY
		Mode.ATTACK:
			if _t % 50 < 2:
				b = InputFrame.BLADE
		Mode.BURST:
			if me.action == FighterState.Action.HITSTUN and me.combo_hits >= 2:
				b = InputFrame.BURST if _t % 4 < 2 else 0
	return InputFrame.new(b, yaw, 0)
