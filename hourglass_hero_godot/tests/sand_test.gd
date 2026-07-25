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
	# Only holds while `sand_flip_base` is 0, which makes `flip_sand()` exactly
	# `max - sand`. A non-zero value breaks it and the double jump (two flips)
	# stops being sand-neutral.
	var cfg := Tuning.cfg
	var worst_drift := 0.0
	var worst_from := 0.0
	for step in 41:
		var start: float = cfg.sand_max * step / 40.0 # covers 0 and max
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

	_finish()


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
