## Sand test: checks the geometry that makes the sand behave like a liquid.
## Pure maths, no game needed:
##
##   godot --headless tests/sand_test.tscn
##
## The smoke test plays the game and never looks at a pixel, so this is the only
## thing standing between `hourglass_shape.gd` and a silent regression.
## Exits 1 on failure, so it can be wired into CI.
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
	# Whatever the glass is doing, the filled area must equal the amount asked
	# for. Get this wrong and the gauge lies about how much time is left.
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
	# This is the whole point: tip the glass and the sand stays horizontal in
	# WORLD space. Before, it turned with the bulb like a solid block.
	var worst_slope := 0.0
	for step in TILT_STEPS:
		var tilt := TAU * step / TILT_STEPS
		var down := Vector2.DOWN.rotated(-tilt)
		var chord: PackedVector2Array = HourglassShape._chord(
			upper, down, HourglassShape._level(upper, down, area * 0.5))
		if chord.size() != 2:
			_check("surface crosses the bulb at %.2f rad" % tilt, false)
			continue
		# Back into world space, where the two ends should sit at the same height.
		worst_slope = maxf(worst_slope,
			absf(chord[0].rotated(tilt).y - chord[1].rotated(tilt).y))
	_check("the free surface stays level in world space", worst_slope < 0.01,
		"ends differ by %.4f px" % worst_slope)

	# --- The tumble lands seamlessly -----------------------------------------
	# At the end of a flip the glass snaps from a half turn back to upright. That
	# is invisible only because the bulbs swap contents at the same moment (see
	# `HourglassMotion.chambers`). If the two ever disagree, the sand jumps.
	var frac := 0.7
	var down_end := Vector2.DOWN.rotated(-PI)
	var last_frame: PackedVector2Array = HourglassShape._clip(upper, down_end,
		HourglassShape._level(upper, down_end, area * (1.0 - frac)))
	var next_frame: PackedVector2Array = HourglassShape._clip(lower, Vector2.DOWN,
		HourglassShape._level(lower, Vector2.DOWN, area * (1.0 - frac)))
	var drift := 0.0
	for p in last_frame:
		var turned := p.rotated(PI)
		var nearest := INF
		for q in next_frame:
			nearest = minf(nearest, turned.distance_to(q))
		drift = maxf(drift, nearest)
	_check("the tumble lands with no jump in the sand", drift < 0.01,
		"sand moves %.4f px across the reset" % drift)

	# --- Flipping is an involution -------------------------------------------
	# `sand_flip_base` is 0, so `flip_sand()` is exactly `max - sand` and two
	# flips must land on the number you started from — bit for bit, not roughly.
	#
	# This is the single most load-bearing fact in the game. The double jump is
	# two flips, so it is sand-neutral by arithmetic rather than by tuning: free
	# while you are full, ruinous while you are empty. Give `sand_flip_base` a
	# non-zero value and the identity breaks, the air jump silently becomes a
	# refuel or a leak, and "Double or Nothing" stops teaching what it teaches.
	var cfg := Tuning.cfg
	var worst_drift := 0.0
	var worst_from := 0.0
	for step in 41:
		var start: float = cfg.sand_max * step / 40.0 # includes both 0 and max
		Game.sand = start
		Game.sand = Game.flip_sand()
		Game.sand = Game.flip_sand()
		if absf(Game.sand - start) > worst_drift:
			worst_drift = absf(Game.sand - start)
			worst_from = start
	_check("flipping twice returns the sand exactly", worst_drift < 0.0001,
		"off by %.6f starting from %.0f — check sand_flip_base" % [worst_drift, worst_from])

	Game.sand = 0.0
	_check("flipping on empty gives back a full glass",
		absf(Game.flip_sand() - cfg.sand_max) < 0.0001)
	Game.sand = cfg.sand_max
	_check("flipping on full gives back nothing", Game.flip_sand() < 0.0001)

	# --- The two-bulb glass is the N-chamber formula at N=2 --------------------
	# Not "close enough": the twelve shipped levels must not move by a pixel, and
	# the cheapest way to know that is to hold the new polygons against the ones
	# written out by hand above.
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

	# Convex, because `_clip`, `_level` and `_pour` are built on it: cutting a
	# convex polygon with a half-plane leaves exactly one convex piece.
	for count in [2, 3, 4]:
		var convex := true
		for i in count:
			convex = convex and _is_convex(HourglassShape.chamber(Vector2(48.0, 72.0), count, i))
		_check("N=%d: every chamber is convex" % count, convex)

	_finish()


## The furthest any corner of `got` sits from the nearest corner of `wanted`.
## Compares the shapes rather than the vertex lists: the same quadrilateral
## written starting from another corner, or wound the other way, is the same
## quadrilateral, and nothing downstream can tell the difference.
func _polygon_drift(got: PackedVector2Array, wanted: PackedVector2Array) -> float:
	if got.size() != wanted.size():
		return INF
	var worst := 0.0
	for p in got:
		var nearest := INF
		for q in wanted:
			nearest = minf(nearest, p.distance_to(q))
		worst = maxf(worst, nearest)
	return worst


## Does the polygon turn the same way at every corner?
func _is_convex(poly: PackedVector2Array) -> bool:
	var n := poly.size()
	var sign_seen := 0.0
	for i in n:
		var a := poly[(i + 1) % n] - poly[i]
		var b := poly[(i + 2) % n] - poly[(i + 1) % n]
		var cross := a.cross(b)
		if absf(cross) < 0.0001:
			continue
		if sign_seen != 0.0 and signf(cross) != sign_seen:
			return false
		sign_seen = signf(cross)
	return true


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
