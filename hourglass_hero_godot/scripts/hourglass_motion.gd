## How one drawn hourglass moves: flip tumble, sand slosh, trickle wobble. One
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
## Wobble speed of the falling trickle.
const STREAM_SPEED := 6.0

## Rotation of the glass, in radians. 0 is upright.
var tilt := 0.0
## Extra tilt of the sand's surfaces on top of `tilt` — the slosh.
var lean := 0.0
var stream_phase := 0.0

var _lean_speed := 0.0


## `speed` is sideways travel in px/s, `shove` its change since the last call —
## a raw speed *difference*, NOT divided by `delta`: it enters as one impulse.
## Both are 0 for a glass that stays put.
func update(delta: float, speed := 0.0, shove := 0.0) -> void:
	if delta <= 0.0:
		return
	stream_phase += delta * STREAM_SPEED

	# A turn is one chamber over `flip_duration`. The glass being regular, it
	# lands visually upright. The spin is read off the config rather than
	# differenced frame to frame, which would spike on the reset to 0.
	var cfg := Tuning.cfg
	var spin := 0.0
	if Game.flip_anim > 0.0 and cfg.flip_duration > 0.0:
		var turn := TAU / float(Game.chamber_count)
		tilt = Game.flip_dir * turn * (1.0 - Game.flip_anim / cfg.flip_duration)
		spin = Game.flip_dir * turn / cfg.flip_duration
	else:
		tilt = 0.0

	# `lean` is the surface's angle in world space, so both terms take the sign of
	# the thing they lag behind.
	var target := clampf(
		spin * SPIN_LAG + speed * DRAG_LEAN / 1000.0, -MAX_LEAN, MAX_LEAN)
	_lean_speed += shove * LEAN_KICK
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
	# Mid-turn every chamber keeps what it held. `Game.chambers` moved to the
	# post-turn arrangement the instant the jump began, so drawing it one step
	# BACK puts each chamber's sand where the chamber still is. The glass snaps
	# upright at the end and the two agree, which is what lands it seamlessly.
	var back := -int(Game.flip_dir) if Game.flip_anim > 0.0 else 0
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		out[i] = clampf(Game.chambers[posmod(i + back, count)] / cap, 0.0, 1.0)
	return out
