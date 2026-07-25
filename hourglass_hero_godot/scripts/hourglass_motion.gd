## How one drawn hourglass moves: the flip tumble, the sand lagging behind it,
## the trickle's wobble.
##
## One instance per glass — the player has one, the HUD gauge has another — so
## they animate independently while sharing the maths. It reads `Game` for the
## flip state; `HourglassShape` stays pure drawing and is told the answers.
class_name HourglassMotion
extends RefCounted

## Radians the sand leans per rad/s of spin. Signed WITH the spin, so the sand
## trails the tumble instead of turning with the walls.
const SPIN_LAG := 0.05
## The shove the sand gets from a sudden change of sideways speed, in rad/s of
## lean speed per px/s gained or lost. This is an impulse, not a force: the
## player's `velocity.x` snaps straight to full speed, so there is no sustained
## acceleration to read — only the jolt at the moment it changes.
const LEAN_KICK := 0.009
## Radians of lean per 1000 px/s of travel. Thick sand keeps trailing while you
## run, long after the jolt has died; without this the glass sits dead level
## mid-sprint. The player feeds both of these; the HUD gauge, bolted to the
## screen, feeds neither.
const DRAG_LEAN := 0.23
## The lean is a damped spring back to level. Slack and fairly damped on
## purpose — this is syrup, not water: it swings over about a second and settles
## after one soft overshoot.
const STIFFNESS := 45.0
const DAMPING := 7.0
## Sand holds a slope, unlike water. This is where it stops leaning.
const MAX_LEAN := 0.45
## Wobble speed of the falling trickle. Cosmetic, never varies.
const STREAM_SPEED := 6.0

## Rotation of the glass, in radians. 0 is upright.
var tilt := 0.0
## Extra tilt of the sand's surfaces, on top of `tilt`. This is the slosh.
var lean := 0.0
var stream_phase := 0.0

var _lean_speed := 0.0


## `speed` is how fast the glass is travelling sideways, in px/s, and `shove` how
## much that changed since the last call. Both are 0 for a glass that stays put.
##
## `shove` is a speed *difference*, deliberately not divided by `delta`: the
## whole change goes into the spring as one impulse, so the same jolt lands
## whatever the frame rate.
func update(delta: float, speed := 0.0, shove := 0.0) -> void:
	if delta <= 0.0:
		return
	stream_phase += delta * STREAM_SPEED

	# A turn is one chamber over the animation's duration. The glass being
	# regular, it lands visually upright and the spin is constant, so it is read
	# straight off the config rather than differenced frame to frame —
	# differencing would spike on the reset back to 0.
	var cfg := Tuning.cfg
	var spin := 0.0
	if Game.flip_anim > 0.0 and cfg.flip_duration > 0.0:
		var turn := TAU / float(Game.chamber_count)
		tilt = Game.flip_dir * turn * (1.0 - Game.flip_anim / cfg.flip_duration)
		spin = Game.flip_dir * turn / cfg.flip_duration
	else:
		tilt = 0.0

	# Where the surface would like to sit: trailing the spin, and dragged back by
	# the travel. `lean` IS the surface's angle in world space, so both terms
	# take the sign of the thing they lag behind.
	var target := clampf(
		spin * SPIN_LAG + speed * DRAG_LEAN / 1000.0, -MAX_LEAN, MAX_LEAN)
	_lean_speed += shove * LEAN_KICK
	_lean_speed += (target - lean) * STIFFNESS * delta
	_lean_speed *= exp(-DAMPING * delta)
	lean = clampf(lean + _lean_speed * delta, -MAX_LEAN, MAX_LEAN)


## Gravity as the glass sees it: straight down in the world, expressed in the
## glass's own frame, then leaned by the slosh. This is the one number that
## makes the sand behave like a liquid rather than a block glued to the walls.
func down() -> Vector2:
	return Vector2.DOWN.rotated(lean - tilt)


## How full each chamber is, 0 to 1, indexed by the slot it is drawn in. The
## size of the array is the chamber count, so this one value tells the shape both
## how many chambers to draw and how much is in each.
func chambers() -> PackedFloat32Array:
	var count := Game.chamber_count
	var cap := maxf(Tuning.cfg.sand_max, 1.0)
	# Mid-turn the neck gates the sand and every chamber keeps what it held.
	# `Game.chambers` moved to the post-turn arrangement the instant the jump
	# began, so drawing it one step BACK — inside a glass that has not finished
	# turning — puts each chamber's sand where the chamber still is. At the end
	# of the animation the glass snaps upright and the two agree exactly, which
	# is what makes the landing seamless.
	var back := -int(Game.flip_dir) if Game.flip_anim > 0.0 else 0
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		out[i] = clampf(Game.chambers[posmod(i + back, count)] / cap, 0.0, 1.0)
	return out
