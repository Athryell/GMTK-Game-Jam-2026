## How one drawn hourglass moves: flip tumble and sand slosh. One
## instance per glass; reads `Game` for the flip state and feeds `HourglassShape`.
class_name HourglassMotion
extends RefCounted

## Radians the sand leans per rad/s of spin. Signed WITH the spin, so it trails.
const SPIN_LAG := 0.05
## Impulse from a change of sideways speed, in rad/s of lean speed per px/s.
const LEAN_KICK := 0.009
## Radians of lean per 1000 px/s of travel. Only the player feeds this and
## `LEAN_KICK`; the screen-fixed HUD gauge feeds neither.
const DRAG_LEAN := 0.23
## The lean is a damped spring back to level.
const STIFFNESS := 45.0
const DAMPING := 7.0
## Max lean, in radians.
const MAX_LEAN := 0.45

## Rotation of the glass, in radians. 0 is upright.
var tilt := 0.0
## Extra tilt of the sand's surfaces on top of `tilt` — the slosh.
var lean := 0.0

var _lean_speed := 0.0
## Which way round the tumble is drawn: +1 normally, -1 while the world is
## upside down. Sampled once per frame so the spin and the sand cannot disagree.
var _mirror := 1.0


## `speed` is sideways travel in px/s, `shove` its change since the last call —
## a raw speed *difference*, NOT divided by `delta`: it enters as one impulse.
## Both are 0 for a glass that stays put.
func update(delta: float, speed := 0.0, shove := 0.0) -> void:
	if delta <= 0.0:
		return
	# A turn is one chamber over `flip_duration`. The glass being regular, it
	# lands visually upright. The spin is read off the config rather than
	# differenced frame to frame, which would spike on the reset to 0.
	var cfg := Tuning.cfg
	var spin := 0.0
	# An upside-down world is seen in a mirror, so the glass tumbles the other way
	# round on screen or it rolls against its own travel. Which chamber the turn
	# lands on is untouched: right is one step round either way up.
	_mirror = Game.gravity_sign
	var mirror := _mirror
	if Game.flip_anim > 0.0 and cfg.flip_duration > 0.0:
		var turn := TAU / float(Game.chamber_count)
		tilt = mirror * Game.flip_dir * turn * (1.0 - Game.flip_anim / cfg.flip_duration)
		spin = mirror * Game.flip_dir * turn / cfg.flip_duration
	else:
		tilt = 0.0

	# `lean` is the surface's angle in world space, so both terms take the sign of
	# the thing they lag behind — and `mirror` on the travel terms, which arrive
	# as screen-x rather than through the already-mirrored spin.
	var target := clampf(
		spin * SPIN_LAG + mirror * speed * DRAG_LEAN / 1000.0, -MAX_LEAN, MAX_LEAN)
	_lean_speed += mirror * shove * LEAN_KICK
	_lean_speed += (target - lean) * STIFFNESS * delta
	_lean_speed *= exp(-DAMPING * delta)
	lean = clampf(lean + _lean_speed * delta, -MAX_LEAN, MAX_LEAN)


## World-down expressed in the glass's own frame, then leaned by the slosh.
func down() -> Vector2:
	return Vector2.DOWN.rotated(lean - tilt)


## How far the sand has turned over inside an inversion zone, 0 to 1. Never a
## rotation: the surface stays square to `down()` throughout.
func invert() -> float:
	return Game.flow_blend


## How full each chamber is, 0 to 1, indexed by the slot it is drawn in. The
## array's size is the chamber count, so this one value tells the shape both how
## many chambers to draw and how much is in each.
func chambers() -> PackedFloat32Array:
	var count := Game.chamber_count
	var cap := maxf(Tuning.cfg.sand_max, 1.0)
	var back := _back()
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		out[i] = clampf(Game.chambers[posmod(i + back, count)] / cap, 0.0, 1.0)
	return out


## One colour per drawn slot: the hue of the plane that slot's chamber puts you
## in once it reaches the top. Empty at two chambers, where FRONT/BACK is already
## unambiguous and the glass is kept pixel-identical to the one that shipped.
##
## Slot `i` sits `i` turns short of the top and a turn carries the plane with it,
## so that slot is plane `Game.plane - i`. A jump of direction `d` brings slot
## `-d` up, whose colour is therefore `Game.plane + d` — precisely the plane you
## are about to land in, which is the whole point of showing them.
##
## Indexed through the same `_back` as [method chambers], so a colour can never
## come adrift from the sand it belongs to mid-turn.
func plane_tints() -> PackedColorArray:
	var count := Game.chamber_count
	if count <= 2:
		return PackedColorArray()
	var back := _back()
	var out := PackedColorArray()
	out.resize(count)
	for i in count:
		out[i] = Palette.PLANE_SOLIDS[posmod(int(Game.plane) - (i + back), count)]
	return out


# ----- The painted glass -----------------------------------------------------
# The player wears the two-bulb glass from `art/sprites/` at EVERY chamber count,
# so it needs its own tumble and its own reading of the sand. Neither can come
# off the rosette's: that turns one chamber per jump and lands seamlessly only
# because it has a chamber's worth of symmetry to land on, which two bulbs at
# three chambers do not — 120 degrees round, a two-bulb glass is lying on its
# side, and the snap back upright is the whole animation undone in a frame.
#
# The HUD gauge is still the rosette, and still says which plane each chamber
# stands for. Nothing below touches it.


## Rotation of the painted glass, in radians. A HALF turn per jump whatever the
## chamber count — the only angle a two-bulb glass comes back upright from.
func sprite_tilt() -> float:
	var cfg := Tuning.cfg
	if Game.flip_anim <= 0.0 or cfg.flip_duration <= 0.0:
		return 0.0
	return _mirror * Game.flip_dir * PI * (1.0 - Game.flip_anim / cfg.flip_duration)


## World-down in the painted glass's own frame, leaned by the slosh. As
## [method down], but against the half turn above.
func sprite_down() -> Vector2:
	return Vector2.DOWN.rotated(lean - sprite_tilt())


## The glass's sand as two bulbs: what you can spend on top, everything else
## pooled below.
##
## Above two chambers there is always exactly one chamber draining — the one the
## clock runs off and the one an empty glass kills you for — so the top bulb is
## that chamber, and the rest of the glass, however it is divided up, becomes the
## pile underneath. Which is what a two-bulb glass has always meant: the sand you
## have left, over the sand you have spent.
##
## Both halves are measured against the WHOLE glass rather than against a bulb,
## so they always add up to one — sand that leaves the top arrives at the bottom,
## which is the only thing a two-bulb picture can honestly say. Against a bulb
## each instead, a three-chamber glass could never fill its lower half past the
## middle however much sand was sitting down there.
##
## It costs the top bulb its brim at four chambers, and should: only one chamber
## drains, so no more than half the glass is ever yours to spend, and a top bulb
## that never fills past half is that rule drawn.
##
## Down to the same swap as [method chambers] mid-turn, so the bulbs change
## places as the glass goes over and it lands with the sand where the picture
## left it. Only whether to swap matters across two bulbs, never which way.
func sprite_fills() -> PackedFloat32Array:
	var count := Game.chamber_count
	var total := maxf(Game.capacity() * float(Game.reach()), 0.001)
	var spendable := clampf(Game.chambers[0] / total, 0.0, 1.0)
	var stored := 0.0
	for i in range(1, count):
		stored += Game.chambers[i]
	stored = clampf(stored / total, 0.0, 1.0)
	if _back() != 0:
		return PackedFloat32Array([stored, spendable])
	return PackedFloat32Array([spendable, stored])


## The step back through the chamber arrays that cancels the step round the
## glass, mid-turn.
##
## Every chamber keeps what it held. `Game.chambers` moved to the post-turn
## arrangement the instant the jump began, so reading it one step BACK puts each
## chamber's contents where the chamber still is. The glass snaps upright at the
## end and the two agree, which is what lands it seamlessly. Through `_mirror`,
## like the tilt it cancels.
func _back() -> int:
	return -int(_mirror * Game.flip_dir) if Game.flip_anim > 0.0 else 0
