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

	# A flip is a half-turn over `flip_duration`. The spin is read off the config
	# rather than differenced frame to frame, which would spike on the reset to 0.
	var cfg := Tuning.cfg
	var spin := 0.0
	if Game.flip_anim > 0.0 and cfg.flip_duration > 0.0:
		tilt = Game.flip_dir * PI * (1.0 - Game.flip_anim / cfg.flip_duration)
		spin = Game.flip_dir * PI / cfg.flip_duration
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
##
## `Game.sand_flow` turns the whole vector over inside an inversion zone, which
## is the entire reversed visual: `draw_glass` reads this both for where sand
## pools and for which way the trickle runs, so one sign change moves both.
func down() -> Vector2:
	return Vector2.DOWN.rotated(lean - tilt) * Game.sand_flow


## How full each bulb is, 0 to 1: `x` the bulb at local -y, `y` the one at +y.
func chambers() -> Vector2:
	var frac := clampf(Game.sand / Tuning.cfg.sand_max, 0.0, 1.0)
	if Game.flip_anim > 0.0:
		# Mid-tumble each bulb keeps what it held. `Game.sand` already jumped to the
		# post-flip figure, and a flip is `max - sand`, so the pre-flip split is its
		# mirror. Holding it fixed is what makes the tumble land seamlessly.
		return Vector2(1.0 - frac, frac)
	return Vector2(frac, 1.0 - frac)
