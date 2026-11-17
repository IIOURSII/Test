class_name FighterState
extends RefCounted
## Tout l'état d'un combattant dans la simulation.
## Rien de visuel ici : seulement des données qu'on peut copier/restaurer
## (indispensable pour le rollback netcode plus tard).

enum Action { NONE, DASH, GUARD_SWITCH, ATTACK, HITSTUN, BLOCK, BLOCKSTUN, PARRIED, BIND }

const GUARD_RIGHT := 1
const GUARD_LEFT := -1

var id: int = 0
var pos: Vector3 = Vector3.ZERO
var vel: Vector3 = Vector3.ZERO
var yaw: int = 0     ## en 1/10000 rad
var pitch: int = 0   ## en 1/10000 rad
var on_ground: bool = true
var crouch: int = 0  ## 0 = debout ... CROUCH_TICKS = accroupi
var guard: int = GUARD_RIGHT

var action: int = Action.NONE
var action_tick: int = 0
var dash_dir: Vector3 = Vector3.ZERO
var dash_cooldown: int = 0
var air_dash_used: bool = false

# --- Coups ---
var move_id: String = ""
var move_tick: int = 0        ## 1 = premier tick du coup
var hit_groups: int = 0       ## groupes de hitbox ayant déjà touché pendant ce coup
var hitstun: int = 0
var hitstop: int = 0          ## micro-freeze : le combattant est figé

# --- Buffer d'inputs ---
var local_tick: int = 0
var last_dir: int = 5
var dir_history: Array = []   ## [[direction numpad, tick de début], ...]
var pending_move: String = "" ## coup demandé mais pas encore lancé
var pending_input: String = ""
var pending_button: String = ""
var pending_age: int = 0

# --- Vie / entraînement ---
var hp: int = 1000
var max_hp: int = 1000
var ticks_since_hit: int = 0
var combo_hits: int = 0
var combo_damage: int = 0
var last_combo_hits: int = 0
var last_combo_damage: int = 0
var last_advantage: int = 0   ## avantage (en ticks) du dernier coup qu'on a placé
var has_advantage_info: bool = false

# --- Défense ---
var parry_timer: int = 0      ## > 0 : un parry parfait est possible
var parry_lockout: int = 0    ## > 0 : impossible de retenter un parry
var guard_gauge: int = 0      ## pleine = garde brisée
var guard_idle: int = 0
var burst_gauge: int = 1000
var burst_buffer: int = 0
var last_adv_on_block: bool = false

# --- Mécanique d'arme (le sens dépend de l'arme ; katana : Zanshin / Tranchant / posture Iai) ---
var weapon_pips: int = 0        ## katana : points de Zanshin
var weapon_gauge: int = 100     ## katana : Tranchant (0..100)
var charge_ticks: int = 0       ## ticks passés en posture (charge)
var in_stance: bool = false
var issen: bool = false         ## le coup en cours est un Issen
var cancel_buffer: int = 0
var pending_fx: String = ""     ## événement visuel à signaler (posture, cancel, Issen...)

# --- Map / objets ---
var floor_y: float = 0.0        ## hauteur du sol sous le combattant (plateformes)
var ground_friction: float = 1.0 ## < 1 : sol glissant (or, glace...)
var potions_left: int = 1
var bind_presses: int = 0       ## clics pendant un bind (clash)
var ki: int = 1000              ## Ki : se dépense pour annuler une action (dash/attaque)
var ki_delay: int = 0           ## ticks avant que le Ki recommence à remonter

var prev_buttons: int = 0


func copy() -> FighterState:
	var c: FighterState = get_script().new()
	c.id = id
	c.pos = pos
	c.vel = vel
	c.yaw = yaw
	c.pitch = pitch
	c.on_ground = on_ground
	c.crouch = crouch
	c.guard = guard
	c.action = action
	c.action_tick = action_tick
	c.dash_dir = dash_dir
	c.dash_cooldown = dash_cooldown
	c.air_dash_used = air_dash_used
	c.move_id = move_id
	c.move_tick = move_tick
	c.hit_groups = hit_groups
	c.hitstun = hitstun
	c.hitstop = hitstop
	c.local_tick = local_tick
	c.last_dir = last_dir
	c.dir_history = dir_history.duplicate(true)
	c.pending_move = pending_move
	c.pending_input = pending_input
	c.pending_button = pending_button
	c.pending_age = pending_age
	c.hp = hp
	c.max_hp = max_hp
	c.ticks_since_hit = ticks_since_hit
	c.combo_hits = combo_hits
	c.combo_damage = combo_damage
	c.last_combo_hits = last_combo_hits
	c.last_combo_damage = last_combo_damage
	c.last_advantage = last_advantage
	c.has_advantage_info = has_advantage_info
	c.parry_timer = parry_timer
	c.parry_lockout = parry_lockout
	c.guard_gauge = guard_gauge
	c.guard_idle = guard_idle
	c.burst_gauge = burst_gauge
	c.burst_buffer = burst_buffer
	c.last_adv_on_block = last_adv_on_block
	c.weapon_pips = weapon_pips
	c.weapon_gauge = weapon_gauge
	c.charge_ticks = charge_ticks
	c.in_stance = in_stance
	c.issen = issen
	c.cancel_buffer = cancel_buffer
	c.pending_fx = pending_fx
	c.floor_y = floor_y
	c.ground_friction = ground_friction
	c.potions_left = potions_left
	c.bind_presses = bind_presses
	c.ki = ki
	c.ki_delay = ki_delay
	c.prev_buttons = prev_buttons
	return c


func yaw_rad() -> float:
	return InputFrame.int_to_angle(yaw)


## Direction "devant" (à plat). En Godot, devant = -Z.
func forward() -> Vector3:
	var a := yaw_rad()
	return Vector3(-sin(a), 0.0, -cos(a))


## Direction "droite" (à plat).
func right() -> Vector3:
	var a := yaw_rad()
	return Vector3(cos(a), 0.0, -sin(a))


func action_name() -> String:
	return Action.keys()[action]


func is_crouching() -> bool:
	return crouch > 3


## Peut-il se défendre (garde / parry) ?
func can_defend() -> bool:
	return action == Action.NONE or action == Action.BLOCK or action == Action.BLOCKSTUN \
			or action == Action.GUARD_SWITCH
