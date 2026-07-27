## Sand test: the geometry in `hourglass_shape.gd`. Pure maths, exits 1 on failure.
##
##   godot --headless tests/sand_test.tscn
extends Node

const TILT_STEPS := 24
const FILLS := [0.02, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99]

var _failures := 0


func _ready() -> void:
	var hw := 24.0
	var hh := 36.0
	var nw := hw * HourglassShape.NECK_RATIO
	var nh := hh * HourglassShape.THROAT_RATIO
	var upper := PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(nw, -nh), Vector2(-nw, -nh),
	])
	var lower := PackedVector2Array([
		Vector2(-nw, nh), Vector2(nw, nh), Vector2(hw, hh), Vector2(-hw, hh),
	])
	var area: float = HourglassShape._area(upper)

	_check("the two bulbs are a half turn apart",
		absf(HourglassShape._area(lower) - area) < 0.001)

	# --- The sand drawn is the sand there is ---------------------------------
	var worst := 0.0
	var worst_at := ""
	for step in TILT_STEPS:
		var tilt := TAU * step / TILT_STEPS
		var down := Vector2.DOWN.rotated(-tilt)
		for fill in FILLS:
			var target: float = area * fill
			var got: float = HourglassShape._area(
				HourglassShape._clip(upper, down, HourglassShape._level(upper, down, target)))
			var err: float = absf(got - target) / area
			if err > worst:
				worst = err
				worst_at = "tilt %.2f rad, %d%% full" % [tilt, int(fill * 100.0)]
	_check("filled area matches the sand asked for", worst < 0.001,
		"off by %.4f%% at %s" % [worst * 100.0, worst_at])

	_check("a full bulb is completely full", absf(area - HourglassShape._area(
		HourglassShape._clip(upper, Vector2.DOWN,
			HourglassShape._level(upper, Vector2.DOWN, area)))) < 0.0001)

	# --- The surface is level, not glued to the walls -------------------------
	var worst_slope := 0.0
	for step in TILT_STEPS:
		var tilt := TAU * step / TILT_STEPS
		var down := Vector2.DOWN.rotated(-tilt)
		var chord: PackedVector2Array = HourglassShape._chord(
			upper, down, HourglassShape._level(upper, down, area * 0.5))
		if chord.size() != 2:
			_check("surface crosses the bulb at %.2f rad" % tilt, false)
			continue
		# Back into world space, where both ends should sit at the same height.
		worst_slope = maxf(worst_slope,
			absf(chord[0].rotated(tilt).y - chord[1].rotated(tilt).y))
	_check("the free surface stays level in world space", worst_slope < 0.01,
		"ends differ by %.4f px" % worst_slope)

	# --- The tumble lands seamlessly -----------------------------------------
	# The end-of-flip snap from a half turn to upright is invisible only because
	# the bulbs swap contents at the same moment (`HourglassMotion.chambers`).
	#
	# `_polygon_drift` answers `inf` when the two clips come out with different
	# corner counts: read "sand moves inf px" as a corner landing on the cut plane.
	var frac := 0.7
	var down_end := Vector2.DOWN.rotated(-PI)
	var last_frame: PackedVector2Array = HourglassShape._clip(upper, down_end,
		HourglassShape._level(upper, down_end, area * (1.0 - frac)))
	var next_frame: PackedVector2Array = HourglassShape._clip(lower, Vector2.DOWN,
		HourglassShape._level(lower, Vector2.DOWN, area * (1.0 - frac)))
	var turned := PackedVector2Array()
	for p in last_frame:
		turned.append(p.rotated(PI))
	var drift := _polygon_drift(turned, next_frame)
	_check("the tumble lands with no jump in the sand", drift < 0.01,
		"sand moves %.4f px across the reset" % drift)

	# --- The reservoir --------------------------------------------------------
	var cfg := Tuning.cfg

	# `sand_max` is ONE chamber's capacity, and the glass carries one per turn of
	# reach.
	for count in [2, 3, 4]:
		Game.arm_glass(count, cfg.sand_start)
		var wanted: float = cfg.sand_max * Game.reach()
		_check("N=%d: the glass holds a bulb per turn out of reach" % count,
			absf(_total(Game.chambers) - wanted) < 0.0001,
			"holds %.0f, wanted %.0f" % [_total(Game.chambers), wanted])

		# The same runway before the first turn is compulsory, whatever the count:
		# more chambers makes the game wider, never faster.
		var even := absf(Game.chambers[0] - cfg.sand_start) < 0.0001
		for i in range(2, count):
			even = even and absf(Game.chambers[i] - Game.chambers[1]) < 0.0001
		_check("N=%d: the top opens at sand_start and the rest share the rest" % count,
			even, "opened %s" % [Game.chambers])

	# Nothing is destroyed, only stranded. Drain and turn as much as you like and
	# the glass still holds what it started with.
	for count in [2, 3, 4]:
		Game.arm_glass(count, cfg.sand_start)
		var before := _total(Game.chambers)
		for i in 20:
			Game.drain(cfg.sand_drain_rate * 0.05)
			Game.rotate_glass(1 if i % 3 == 0 else -1)
		_check("N=%d: sand is conserved across drains and turns" % count,
			absf(_total(Game.chambers) - before) < 0.01,
			"%.4f → %.4f" % [before, _total(Game.chambers)])

	# --- Two chambers reproduce the shipped flip, exactly ---------------------
	# `sand_flip_base` is 0, so a turn is `max - sand` and two turns must land on
	# the number you started from — bit for bit. The double jump is two turns, so
	# it is sand-neutral by arithmetic rather than by tuning; a non-zero
	# `sand_flip_base` breaks the identity and makes the air jump a refuel or a leak.
	var worst_drift := 0.0
	var worst_from := 0.0
	var worst_flip := 0.0
	for step in 41:
		var start: float = cfg.sand_max * step / 40.0 # covers 0 and max
		Game.arm_glass(2, start)
		# One turn must give back exactly what the old `max - sand` gave back.
		Game.rotate_glass(1)
		worst_flip = maxf(worst_flip,
			absf(Game.sand - clampf(cfg.sand_max - start + cfg.sand_flip_base, 0.0, cfg.sand_max)))
		Game.rotate_glass(1)
		if absf(Game.sand - start) > worst_drift:
			worst_drift = absf(Game.sand - start)
			worst_from = start
	_check("N=2: one turn is the shipped `max - sand` flip, to the bit", worst_flip < 0.0001,
		"off by %.6f" % worst_flip)
	_check("N=2: turning twice returns the sand exactly", worst_drift < 0.0001,
		"off by %.6f starting from %.0f — check sand_flip_base" % [worst_drift, worst_from])

	Game.arm_glass(2, 0.0)
	Game.rotate_glass(1)
	_check("N=2: turning on empty gives back a full glass",
		absf(Game.sand - cfg.sand_max) < 0.0001, "got %.4f" % Game.sand)
	Game.arm_glass(2, cfg.sand_max)
	Game.rotate_glass(1)
	_check("N=2: turning on full gives back nothing", Game.sand < 0.0001,
		"got %.4f" % Game.sand)

	# --- The sand you can spend is the sand up top ---------------------------
	# At three and four chambers there is exactly one draining chamber, so
	# `danger()`, the HUD, the player's light and the sweat all keep reading one
	# number and none of them had to learn anything.
	Game.arm_glass(4, 2400.0)
	_check("N=4: `sand` is the top chamber, not the whole glass",
		absf(Game.sand - 2400.0) < 0.0001, "got %.4f" % Game.sand)

	# What leaves the top arrives below it. At three chambers it arrives split in
	# two, which is why a turn can never hand back more than half of what you
	# spent — the whole lesson of the trefoil level.
	Game.arm_glass(3, 3000.0)
	var below := Game.chambers[1]
	Game.drain(600.0)
	_check("N=3: the fall splits half and half",
		absf(Game.chambers[1] - Game.chambers[2]) < 0.0001
			and absf(Game.chambers[1] - (below + 300.0)) < 0.0001,
		"chambers %s" % [Game.chambers])

	# At four chambers it arrives whole — but in the chamber two turns away.
	Game.arm_glass(4, 3000.0)
	Game.drain(600.0)
	_check("N=4: the fall arrives whole, in the bottom chamber",
		absf(Game.chambers[2] - 3600.0) < 0.0001
			and absf(Game.chambers[1] - 3000.0) < 0.0001
			and absf(Game.chambers[3] - 3000.0) < 0.0001,
		"chambers %s" % [Game.chambers])

	# And the sealed chambers are sealed: a glass whose top is empty is dead even
	# with sand still in it, which is what makes hesitation cost something.
	Game.arm_glass(4, 100.0)
	var sealed_before := Game.chambers[2]
	Game.drain(500.0)
	_check("N=4: draining a chamber dry stops there", Game.sand < 0.0001,
		"top holds %.4f" % Game.sand)
	# Written as a gain rather than a figure: what the sealed chambers hold depends
	# on how much the level put on top.
	_check("N=4: and the sand it lost is in the bottom, not gone",
		absf(Game.chambers[2] - sealed_before - 100.0) < 0.0001,
		"chambers %s" % [Game.chambers])

	# --- The two-bulb glass is the N-chamber formula at N=2 --------------------
	# Not "close enough": the shipped levels must not move by a pixel.
	var drift_upper := _polygon_drift(HourglassShape.chamber(Vector2(48.0, 72.0), 2, 0), upper)
	_check("chamber 0 of a two-chamber glass IS the upper bulb", drift_upper < 0.0001,
		"corners move %.6f px" % drift_upper)
	var drift_lower := _polygon_drift(HourglassShape.chamber(Vector2(48.0, 72.0), 2, 1), lower)
	_check("chamber 1 of a two-chamber glass IS the lower bulb", drift_lower < 0.0001,
		"corners move %.6f px" % drift_lower)

	# Every chamber holds the same, whatever the count — the sand economy hands
	# each one the same amount at rest and expects it to read the same depth.
	for count in [2, 3, 4]:
		var areas: Array[float] = []
		for i in count:
			areas.append(HourglassShape._area(
				HourglassShape.chamber(Vector2(48.0, 72.0), count, i)))
		var spread: float = areas.max() - areas.min()
		_check("N=%d: every chamber has the same capacity" % count,
			spread / areas.max() < 0.001, "areas %s" % [areas])

	# A chamber has to stay a chamber as the count goes up: every chamber is handed
	# the same share of a fixed budget and drains at a fixed rate, so a lobe holding
	# a fifth of the shipped bulb would empty in a fifth of the time. A rosette lobe
	# is necessarily smaller than a half-glass; smaller than HALF of one is `_span`
	# being wrong.
	var bulb: float = HourglassShape._area(HourglassShape.chamber(Vector2(48.0, 72.0), 2, 0))
	for count in [3, 4]:
		var share: float = HourglassShape._area(
			HourglassShape.chamber(Vector2(48.0, 72.0), count, 0)) / bulb
		_check("N=%d: a chamber holds a workable share of the shipped bulb" % count,
			share > 0.5 and share <= 1.0, "holds %.3f of it" % share)

	# Convex, because `_clip`, `_level` and `_pour` are built on it: cutting a
	# convex polygon with a half-plane leaves exactly one convex piece.
	for count in [2, 3, 4]:
		var convex := true
		for i in count:
			convex = convex and _is_convex(HourglassShape.chamber(Vector2(48.0, 72.0), count, i))
		_check("N=%d: every chamber is convex" % count, convex)

	# --- Chambers keep out of each other's way --------------------------------
	# Chamber `i` owns the wedge `PI / count` either side of its axis and must stay
	# inside it: overlapping chambers draw their sand twice, and `shell` threads one
	# ring through every chamber, which is only simple while they are disjoint.
	#
	# The two ends are held apart by unrelated mechanisms, so they get a check each.
	# Rolled into one they would report the wrong cause: the far corners merely
	# happen to sit under `WEDGE_FILL`, so tightening that constant would fail a
	# check pointing at the constant instead of at `sin`.
	for count in [2, 3, 4]:
		var worst_neck := 0.0
		var worst_far := 0.0
		for i in count:
			var axis := ChamberLayout.axis(count, i)
			var poly := HourglassShape.chamber(Vector2(48.0, 72.0), count, i)
			var wedge := PI / float(count)
			worst_far = maxf(worst_far, absf(axis.angle_to(poly[0])) / wedge)
			worst_far = maxf(worst_far, absf(axis.angle_to(poly[1])) / wedge)
			worst_neck = maxf(worst_neck, absf(axis.angle_to(poly[2])) / wedge)
			worst_neck = maxf(worst_neck, absf(axis.angle_to(poly[3])) / wedge)
		# The cap in `chamber` puts the neck corners exactly on `WEDGE_FILL`
		# wherever it bites, so this is an equality as much as a bound.
		_check("N=%d: the neck corners stop where WEDGE_FILL says" % count,
			worst_neck <= HourglassShape.WEDGE_FILL + 0.0001,
			"a neck corner sits %.4f of the way to the wedge wall" % worst_neck)
		# `sin` promises only that the far corners stay inside the wedge, and
		# STRICTLY inside: a corner sitting exactly on the wall is a corner shared
		# with the neighbouring chamber, which pinches the ring to a point right
		# where `shell` has to pass through it.
		_check("N=%d: the far corners stay inside the wedge" % count,
			worst_far < 1.0 - 0.0001,
			"a far corner sits %.4f of the way to the wedge wall" % worst_far)

	for count in [2, 3, 4]:
		for i in count:
			var other: int = (i + 1) % count
			var shared := Geometry2D.intersect_polygons(
				HourglassShape.chamber(Vector2(48.0, 72.0), count, i),
				HourglassShape.chamber(Vector2(48.0, 72.0), count, other))
			# Named low-then-high so that at two chambers, where "the next one
			# round" from either chamber is the other one, both passes print the
			# same line and read as the one assertion they are.
			_check("N=%d: chambers %d and %d do not overlap"
				% [count, mini(i, other), maxi(i, other)], shared.is_empty())

	# --- One ring, through every chamber --------------------------------------
	# `shell` is what Task 3 will hand to `draw_colored_polygon`, and it is only a
	# glass while it stays a simple closed curve.
	var shipped_shell := PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(nw, -nh), Vector2(nw, nh),
		Vector2(hw, hh), Vector2(-hw, hh), Vector2(-nw, nh), Vector2(-nw, -nh),
	])
	var shell_drift := _ring_drift(HourglassShape.shell(Vector2(48.0, 72.0), 2), shipped_shell)
	_check("the two-chamber ring IS the glass that ships today", shell_drift < 0.0001,
		"corners move %.6f px" % shell_drift)

	for count in [2, 3, 4]:
		_check("N=%d: the ring does not cross itself" % count,
			not _self_intersects(HourglassShape.shell(Vector2(48.0, 72.0), count)))

	# --- The inversion zone reverses the clock --------------------------------
	# The flow is asked of a Godot group, so a stub in that group drives it and
	# this bench stays pure. Real containment is checked by playing the game.
	_check("no zones means the sand flows normally", Game.poll_sand_flow() > 0.0)

	var empty_zone := _StubZone.new(false)
	var full_zone := _StubZone.new(true)
	add_child(empty_zone)
	add_child(full_zone)

	empty_zone.add_to_group(Game.INVERSION_GROUP)
	_check("a zone the player is NOT in leaves the flow alone",
		Game.poll_sand_flow() > 0.0)

	full_zone.add_to_group(Game.INVERSION_GROUP)
	_check("standing in a zone reverses the flow", Game.poll_sand_flow() < 0.0)

	# The flow is a direction, not a total: overlapping zones must not stack.
	var second := _StubZone.new(true)
	add_child(second)
	second.add_to_group(Game.INVERSION_GROUP)
	_check("overlapping zones invert once, not twice",
		is_equal_approx(Game.poll_sand_flow(), -1.0),
		"flow = %.2f" % Game.sand_flow)
	# Out of the group by hand: `queue_free` only lands at the end of the frame,
	# and a zone still in the group is still asked.
	second.remove_from_group(Game.INVERSION_GROUP)
	second.queue_free()
	full_zone.remove_from_group(Game.INVERSION_GROUP)
	_check("leaving every zone restores the normal flow",
		Game.poll_sand_flow() > 0.0)

	# --- Danger measures the death that is actually active --------------------
	# `Palette.sand()` feeds the sprite, the HUD and the player's light off this
	# one number, so reading the wrong end lies in three places at once.
	full_zone.add_to_group(Game.INVERSION_GROUP)
	Game.poll_sand_flow()
	# `sand` is what the draining chamber holds, so `arm_glass` is how you set it.
	Game.arm_glass(2, cfg.sand_max)
	_check("inverted, a FULL glass is maximum danger",
		is_equal_approx(Game.danger(), 1.0), "danger = %.3f" % Game.danger())
	Game.arm_glass(2, 0.0)
	_check("inverted, an EMPTY glass is safe",
		is_zero_approx(Game.danger()), "danger = %.3f" % Game.danger())

	full_zone.remove_from_group(Game.INVERSION_GROUP)
	Game.poll_sand_flow()
	Game.arm_glass(2, 0.0)
	_check("normally, an EMPTY glass is maximum danger",
		is_equal_approx(Game.danger(), 1.0), "danger = %.3f" % Game.danger())
	Game.arm_glass(2, cfg.sand_max)
	_check("normally, a FULL glass is safe", is_zero_approx(Game.danger()),
		"danger = %.3f" % Game.danger())

	# --- The drawn sand turns over without the glass turning over -------------
	# Rotating gravity through half a turn swings the pile round the bulb like a
	# clock hand, and reads as the glass spinning. `down()` must stay put.
	full_zone.add_to_group(Game.INVERSION_GROUP)
	Game.poll_sand_flow()
	var motion := HourglassMotion.new()

	Game.advance_flow_blend(1.0 / 60.0)
	_check("entering a zone does not tip the glass",
		motion.down().is_equal_approx(Vector2.DOWN), "down = %v" % motion.down())
	_check("entering a zone starts the sand turning over, but only just",
		motion.invert() > 0.0 and motion.invert() < 0.1,
		"invert = %.3f" % motion.invert())

	Game.advance_flow_blend(cfg.flow_turn_duration / 2.0)
	_check("halfway through, the sand is halfway over",
		absf(motion.invert() - 0.5) < 0.05, "invert = %.3f" % motion.invert())

	Game.advance_flow_blend(cfg.flow_turn_duration)
	_check("turned over, the sand runs entirely the other way",
		is_equal_approx(motion.invert(), 1.0), "invert = %.3f" % motion.invert())
	_check("the glass is still upright at the end of it",
		motion.down().is_equal_approx(Vector2.DOWN), "down = %v" % motion.down())

	full_zone.remove_from_group(Game.INVERSION_GROUP)
	Game.poll_sand_flow()
	Game.advance_flow_blend(cfg.flow_turn_duration)
	_check("leaving the zone runs the sand back down the glass",
		is_zero_approx(motion.invert()), "invert = %.3f" % motion.invert())

	# The trickle survives the reversal.
	var glass := Vector2(hw * 2.0, hh * 2.0)
	for dir in [Vector2.DOWN, Vector2.UP]:
		_check("the trickle pours at full rate with gravity %v" % dir,
			HourglassShape.trickle_rate(glass, dir) > 0.99)

	# The pile rises in one piece and keeps its sand the whole way.
	var held: float = area * 0.5
	var climbed := -INF
	var worst_loss := 0.0
	var jumped := false
	for step in 21:
		var lift: float = step / 20.0
		var slab: PackedVector2Array = HourglassShape.pile(upper, Vector2.DOWN, held, lift)
		# Same slack as the accuracy check above: `_level` bisects, it does not solve.
		worst_loss = maxf(worst_loss, absf(HourglassShape._area(slab) - held) / area)
		var height := -_centre(slab).y
		if height < climbed - 0.01:
			jumped = true
		climbed = maxf(climbed, height)
	_check("the pile keeps its sand all the way up", worst_loss < 0.002,
		"off by %.4f%%" % [worst_loss * 100.0])
	_check("and never drops back down on the way", not jumped)

	var settled_low: PackedVector2Array = HourglassShape.pile(upper, Vector2.DOWN, held, 0.0)
	var settled_high: PackedVector2Array = HourglassShape.pile(upper, Vector2.DOWN, held, 1.0)
	_check("at rest it sits on the floor of its bulb",
		absf(_centre(settled_low).y - _centre(HourglassShape._clip(upper, Vector2.DOWN,
			HourglassShape._level(upper, Vector2.DOWN, held))).y) < 0.01)
	_check("turned over it clings to the ceiling of its bulb",
		_centre(settled_high).y < _centre(settled_low).y - 1.0,
		"%.1f vs %.1f" % [_centre(settled_high).y, _centre(settled_low).y])

	# The trickle is the gap the two piles leave, so it is joined to both at every
	# step, and rides the sand rather than stretching between it.
	var shortest := INF
	var longest := 0.0
	for step in 21:
		var lift: float = step / 20.0
		var top: PackedVector2Array = HourglassShape.pile(upper, Vector2.DOWN, held, lift)
		var bottom: PackedVector2Array = HourglassShape.pile(lower, Vector2.DOWN, held, lift)
		var span: float = HourglassShape._reach(bottom, Vector2.DOWN, false, nh) \
			- HourglassShape._reach(top, Vector2.DOWN, true, -nh)
		shortest = minf(shortest, span)
		longest = maxf(longest, span)
	_check("the trickle always has both piles to hold on to", shortest > 0.0,
		"shortest span %.2f px" % shortest)
	_check("and its length barely changes on the way",
		longest - shortest < hh * 0.12, "%.1f px to %.1f px" % [shortest, longest])

	# --- And it turns over with the flow --------------------------------------
	# Sand in flight sits between the neck and the chamber it is heading FOR, so
	# reversing the flow has to carry the thread across the neck with it.
	var falls: PackedVector2Array = HourglassShape.trickle_segment(
		glass, 2, 0, 1, Vector2.DOWN, 0.0)
	var climbs: PackedVector2Array = HourglassShape.trickle_segment(
		glass, 2, 0, 1, Vector2.DOWN, 1.0)
	_check("the falling thread hangs below the neck",
		falls[1].y > 0.0 and falls[1].y > falls[0].y,
		"runs %v to %v" % [falls[0], falls[1]])
	_check("and the climbing one is carried above it",
		climbs[1].y < 0.0 and climbs[1].y < climbs[0].y,
		"runs %v to %v" % [climbs[0], climbs[1]])
	_check("the reversal is a mirror through the neck, not a shift",
		falls[0].is_equal_approx(-climbs[0]) and falls[1].is_equal_approx(-climbs[1]),
		"%v/%v against %v/%v" % [falls[0], falls[1], climbs[0], climbs[1]])
	# Straight from one side to the other would pop a whole column across the neck
	# in a frame; it has to shrink away and grow back instead.
	var handover: PackedVector2Array = HourglassShape.trickle_segment(
		glass, 2, 0, 1, Vector2.DOWN, 0.5)
	_check("and it passes through nothing at the hand-over",
		handover[0].distance_to(handover[1]) < 0.001,
		"still %.3f px long" % handover[0].distance_to(handover[1]))

	empty_zone.queue_free()
	full_zone.queue_free()

	_finish()


## How far the two polygons sit apart as SHAPES — the Hausdorff distance, the
## worst corner-to-nearest-corner gap looked for in BOTH directions. One
## direction is not a distance: a quadrilateral collapsed onto three corners has
## every corner of its own sitting on a corner of the original, and only the
## other direction finds the lost corner with nothing near it.
func _polygon_drift(got: PackedVector2Array, wanted: PackedVector2Array) -> float:
	if got.size() != wanted.size():
		return INF
	return maxf(_one_way_drift(got, wanted), _one_way_drift(wanted, got))


func _one_way_drift(from: PackedVector2Array, to: PackedVector2Array) -> float:
	var worst := 0.0
	for p in from:
		var nearest := INF
		for q in to:
			nearest = minf(nearest, p.distance_to(q))
		worst = maxf(worst, nearest)
	return worst


## The furthest a corner of `got` sits from the corner facing it in `wanted`,
## over whichever rotation of the ring lines the two up best.
##
## Rotation only, never reversal — that is the point of having it as well as
## `_polygon_drift`: a ring that comes back correct but backwards means `shell`'s
## documented corner order has changed underneath it.
func _ring_drift(got: PackedVector2Array, wanted: PackedVector2Array) -> float:
	var n := got.size()
	if n == 0 or n != wanted.size():
		return INF
	var best := INF
	for offset in n:
		var worst := 0.0
		for i in n:
			worst = maxf(worst, got[(i + offset) % n].distance_to(wanted[i]))
		best = minf(best, worst)
	return best


## Does a closed ring cross itself anywhere? Every pair of edges that do not
## already share a corner — neighbours meet by construction and that is not a
## crossing.
func _self_intersects(ring: PackedVector2Array) -> bool:
	var n := ring.size()
	for i in n:
		for j in range(i + 1, n):
			if (j + 1) % n == i or (i + 1) % n == j:
				continue
			var hit: Variant = Geometry2D.segment_intersects_segment(
				ring[i], ring[(i + 1) % n], ring[j], ring[(j + 1) % n])
			if hit != null:
				return true
	return false


## Does the polygon turn the same way at every corner?
##
## Measured as the sine of the angle between the edges, not as the raw cross
## product: that is dimensionless, so one threshold reads the same on the 48 px
## player and on the HUD gauge. A zero-length edge is skipped.
func _is_convex(poly: PackedVector2Array) -> bool:
	var n := poly.size()
	var sign_seen := 0.0
	for i in n:
		var a := poly[(i + 1) % n] - poly[i]
		var b := poly[(i + 2) % n] - poly[(i + 1) % n]
		if a.length() < 0.0001 or b.length() < 0.0001:
			continue
		var turn := a.cross(b) / (a.length() * b.length())
		if absf(turn) < 0.000001:
			continue
		if sign_seen != 0.0 and signf(turn) != sign_seen:
			return false
		sign_seen = signf(turn)
	return true


func _total(cells: PackedFloat32Array) -> float:
	var out := 0.0
	for v in cells:
		out += v
	return out


## Average of a polygon's corners. Not the true centroid, but enough to say which
## end of a bulb a pile is sitting at.
func _centre(poly: PackedVector2Array) -> Vector2:
	if poly.is_empty():
		return Vector2.ZERO
	var total := Vector2.ZERO
	for p in poly:
		total += p
	return total / poly.size()


func _check(name: String, passed: bool, detail := "") -> void:
	if passed:
		print("  ok   ", name)
	else:
		_failures += 1
		print("  FAIL ", name, ("  (%s)" % detail) if detail != "" else "")


func _finish() -> void:
	print("")
	print("All checks passed." if _failures == 0 else "%d check(s) FAILED." % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## Stands in for an InversionZone: `Game` only ever asks a zone one question,
## so the flow can be tested without a scene tree full of physics.
class _StubZone extends Node:
	var _occupied: bool

	func _init(occupied: bool) -> void:
		_occupied = occupied

	func contains_player() -> bool:
		return _occupied
