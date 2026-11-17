class_name Sfx
extends Node
## Sons placeholder SYNTHÉTISÉS au lancement (aucun fichier audio nécessaire) :
## sifflement de lame, impact tranchant, impact lourd, choc de pommeau, "shing" métallique, dash.
## Ils seront remplacés par de vrais sons plus tard : il suffira de changer play().

const SR := 22050
const VOICES := 16

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _rng := RandomNumberGenerator.new()


func setup() -> void:
	_rng.seed = 7
	_streams["swish"] = _swish(0.22, 700.0, 3400.0, 0.55)
	_streams["swish_heavy"] = _swish(0.34, 380.0, 2300.0, 0.75)
	_streams["swish_soft"] = _swish(0.16, 350.0, 1400.0, 0.4)
	_streams["dash"] = _swish(0.2, 250.0, 1200.0, 0.45)
	_streams["hit"] = _hit(0.38, 105.0, 55.0, 13.0, 0.95)
	_streams["hit_heavy"] = _hit(0.7, 80.0, 30.0, 6.0, 1.0)
	_streams["thock"] = _thock()
	_streams["shing"] = _shing(0.45)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(sound: String, volume_db: float = 0.0, pitch_var: float = 0.06) -> void:
	if not _streams.has(sound):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + _rng.randf_range(-pitch_var, pitch_var)
	p.play()


# ------------------------------------------------------------ synthèse

static func _coef(fc: float) -> float:
	return 1.0 - exp(-TAU * fc / SR)


## Sifflement : bruit filtré dont la fréquence monte puis redescend.
func _swish(dur: float, f_lo: float, f_hi: float, amp: float) -> AudioStreamWAV:
	var n := int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp1 := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / float(n)
		var env := sin(PI * pow(t, 0.55))
		env *= env
		var fc := lerpf(f_lo, f_hi, sin(PI * pow(t, 0.7)))
		var x := _rng.randf_range(-1.0, 1.0)
		lp1 += _coef(fc) * (x - lp1)
		lp2 += _coef(fc * 0.3) * (lp1 - lp2)
		out[i] = (lp1 - lp2) * env
	return _to_wav(out, amp)


## Impact : claquement aigu (tranchant) + "boum" grave qui descend + craquement.
func _hit(dur: float, f0: float, f1: float, decay: float, amp: float) -> AudioStreamWAV:
	var n := int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var hp := 0.0
	var crunch := 0.0
	for i in n:
		var t := float(i) / SR
		var f := lerpf(f1, f0, exp(-t * 18.0))
		phase += TAU * f / SR
		var thump := sin(phase) * exp(-t * decay)
		var x := _rng.randf_range(-1.0, 1.0)
		hp += _coef(2500.0) * (x - hp)
		var slice := (x - hp) * exp(-t * 60.0)
		crunch += _coef(1100.0) * (x - crunch)
		var cr := crunch * exp(-t * 20.0) * 3.0
		out[i] = tanh((thump * 1.0 + slice * 0.8 + cr * 0.6) * 1.6)
	return _to_wav(out, amp)


## Choc sourd de pommeau / coup d'épaule.
func _thock() -> AudioStreamWAV:
	var n := int(0.16 * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / SR
		var f := lerpf(140.0, 280.0, exp(-t * 40.0))
		phase += TAU * f / SR
		var body := sin(phase) * exp(-t * 32.0)
		var click := _rng.randf_range(-1.0, 1.0) * exp(-t * 350.0)
		out[i] = tanh((body + click * 0.6) * 1.5)
	return _to_wav(out, 0.85)


## "Shing" métallique (changement de garde ; servira aussi au parry et au clash).
func _shing(dur: float) -> AudioStreamWAV:
	var n := int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var partials := [[1870.0, 6.0, 1.0], [2630.0, 8.0, 0.7], [3920.0, 10.0, 0.5], [5210.0, 13.0, 0.35], [6780.0, 16.0, 0.25]]
	var hp := 0.0
	for i in n:
		var t := float(i) / SR
		var s := 0.0
		for p in partials:
			s += sin(TAU * float(p[0]) * t) * exp(-t * float(p[1])) * float(p[2])
		var x := _rng.randf_range(-1.0, 1.0)
		hp += _coef(3000.0) * (x - hp)
		var scrape := (x - hp) * exp(-t * 30.0)
		out[i] = s * 0.5 + scrape * 0.5
	return _to_wav(out, 0.5)


static func _to_wav(samples: PackedFloat32Array, peak_target: float) -> AudioStreamWAV:
	var peak := 0.0001
	for v in samples:
		peak = maxf(peak, absf(v))
	var gain := peak_target / peak
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = data
	return w
