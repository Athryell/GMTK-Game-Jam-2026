## Chamber layout test: the glass's geometry and its consequences, with nothing
## rendered and no game running.
##
##   godot --headless tests/chamber_layout_test.tscn
##
## Everything here is a claim the design makes in prose. If one of them stops
## holding, a level stops teaching what it was built to teach.
extends Node

var _failures := 0


func _ready() -> void:
	_frame()
	_roles()
	_pour_map()
	_trefoil_lesson()
	_quarters_lesson()
	_tumble_mirror()
	_sand_budget()
	_finish()


## Where the chambers actually are. Everything below this is invariant under
## turning the glass the other way — the chambers are symmetric about the
## vertical at every count the game uses, so the roles and the pour map come out
## identical for a glass that spins backwards. Only this checks the handedness,
## and the drawing and the per-jump rotation are both built on it.
func _frame() -> void:
	for count in [2, 3, 4]:
		_check("N=%d: chamber 0 points straight up" % count,
			ChamberLayout.axis(count, 0).is_equal_approx(Vector2.UP))
		var unit := true
		for i in count:
			unit = unit and is_equal_approx(ChamberLayout.axis(count, i).length(), 1.0)
		_check("N=%d: every axis is a unit vector" % count, unit)

	# Clockwise ON SCREEN, where y grows downward: a quarter turn from up is to
	# the RIGHT. Turn the other way and this is the only check that notices.
	_check("N=4: chamber 1 is a quarter turn clockwise, to the right",
		ChamberLayout.axis(4, 1).is_equal_approx(Vector2.RIGHT),
		"it points %s" % ChamberLayout.axis(4, 1))


## §1 of the spec: which chambers drain, which receive, which are sealed.
func _roles() -> void:
	var expected := {
		2: [ChamberLayout.Role.UPPER, ChamberLayout.Role.LOWER],
		3: [ChamberLayout.Role.UPPER, ChamberLayout.Role.LOWER, ChamberLayout.Role.LOWER],
		4: [ChamberLayout.Role.UPPER, ChamberLayout.Role.LEVEL,
			ChamberLayout.Role.LOWER, ChamberLayout.Role.LEVEL],
	}
	for count in expected:
		var got: Array[int] = []
		for i in count:
			got.append(ChamberLayout.role(count, i))
		_check("N=%d: the roles come out of the angles" % count, got == expected[count],
			"got %s, wanted %s" % [got, expected[count]])


## The "opposite chambers only" rule and the "half and half" rule are the same
## rule seen at two chamber counts. Neither is written down anywhere.
func _pour_map() -> void:
	_check("N=2: the top pours straight into the bottom",
		ChamberLayout.targets(2, 0) == ([1] as Array[int]))
	_check("N=4: the top pours into the bottom and into neither side",
		ChamberLayout.targets(4, 0) == ([2] as Array[int]))
	var three := ChamberLayout.targets(3, 0)
	three.sort()
	_check("N=3: the top splits half and half", three == ([1, 2] as Array[int]),
		"got %s" % [three])

	# A chamber that receives does not also pour. Checked at N=2 and N=3 because
	# the N=4 sealed chambers are the only case checked elsewhere.
	_check("a chamber that catches sand does not also drop it",
		ChamberLayout.targets(2, 1).is_empty() and ChamberLayout.targets(3, 1).is_empty())


## The three-chamber lesson: whichever way you turn, you turn INTO a chamber
## that just caught sand — but only one of them, and the sand in the other is
## stranded until you come back round. Turning the same way three times collects
## both halves; alternating between two chambers never touches the third.
func _trefoil_lesson() -> void:
	var caught := ChamberLayout.targets(3, 0)
	_check("N=3: turning either way lands on a chamber that caught sand",
		caught.has(posmod(1, 3)) and caught.has(posmod(-1, 3)),
		"the top pours into %s" % [caught])

	# Alternating visits {0, 1} forever. Slot 2 caught half of everything that
	# drained and is never turned into — which is the whole trap.
	var visited := {}
	var slot := 0
	for turn in 6:
		slot = posmod(slot + (1 if turn % 2 == 0 else -1), 3)
		visited[slot] = true
	var stranded: Array[int] = []
	for i in caught:
		if not visited.has(i):
			stranded.append(i)
	_check("N=3: alternating strands the sand in a chamber it never turns into",
		stranded.size() == 1 and visited.size() == 2,
		"visited %s, stranded %s" % [visited.keys(), stranded])


## The four-chamber lesson: the sand you drained arrives whole rather than split,
## but it lands two turns away, behind a chamber that is sealed. So a refill has
## to be committed to one turn ahead of needing it — and turning back does not
## just waste a turn, it returns the glass to the arrangement before it.
func _quarters_lesson() -> void:
	var caught := ChamberLayout.targets(4, 0)

	# The two chambers you pass through on the way are sealed: they catch
	# nothing, and they hand nothing on. Checked first because nothing here
	# indexes `caught` — a broken pour map should not take these down with it.
	for i in [posmod(1, 4), posmod(-1, 4)]:
		_check("N=4: chamber %d is sealed, so passing through it gains nothing" % i,
			ChamberLayout.role(4, i) == ChamberLayout.Role.LEVEL
				and not caught.has(i) and ChamberLayout.targets(4, i).is_empty())

	_check("N=4: the fall arrives whole, in one chamber", caught.size() == 1)
	# The size test is repeated so the index is short-circuited: a pour map that
	# returns nothing must FAIL this check, not crash out of the function and
	# silently skip whatever came after it.
	_check("N=4: and that chamber is two turns away, not one",
		caught.size() == 1 and caught[0] == posmod(0 + 2, 4), "it landed in %s" % [caught])


## The tumble seen in a mirror: upside down the glass rolls the other way, and
## the sand drawn mid-turn follows the drawing. One claim, really — the turn ends
## a whole chamber round and then snaps upright, and that seam is only invisible
## if the step back through the array cancels the step round the glass.
func _tumble_mirror() -> void:
	var count := 4
	var cap: float = Tuning.cfg.sand_max
	Game.chamber_count = count
	# All different, so a wrong step by any amount shows up.
	Game.chambers = PackedFloat32Array([0.1 * cap, 0.2 * cap, 0.3 * cap, 0.4 * cap])
	Game.flip_dir = 1.0
	var motion := HourglassMotion.new()
	var turn := TAU / float(count)

	for mirror in [1.0, -1.0]:
		Game.gravity_sign = mirror
		# The last instant of the turn, then the first instant after it.
		Game.flip_anim = 0.0001
		motion.update(1.0 / 60.0)
		var mid := motion.chambers()
		var tilt := motion.tilt
		Game.flip_anim = 0.0
		motion.update(1.0 / 60.0)
		var after := motion.chambers()

		_check("gravity %+.0f: the glass rolls the way the world does" % mirror,
			is_equal_approx(signf(tilt), mirror * Game.flip_dir)
				and absf(absf(tilt) - turn) < 0.01,
			"tilt %.3f, a turn being %.3f" % [tilt, turn])

		var step := int(mirror * Game.flip_dir)
		var seamless := true
		for i in count:
			seamless = seamless and is_equal_approx(mid[i], after[posmod(i - step, count)])
		_check("gravity %+.0f: and the sand does not jump at the seam" % mirror,
			seamless, "%s became %s" % [mid, after])

	Game.gravity_sign = 1.0
	Game.flip_anim = 0.0


## What the glass is allowed to hold. Every count gives the same runway before
## the first turn, and none of them ever puts more on the clock than one bulb —
## which is what three chambers used to do, peaking a whole bulb and a quarter.
func _sand_budget() -> void:
	var cap: float = Tuning.cfg.sand_max
	for count in [2, 3, 4]:
		Game.arm_glass(count, Tuning.cfg.sand_start)
		var total := 0.0
		for c in Game.chambers:
			total += c
		_check("N=%d: the glass carries a bulb per turn out of reach" % count,
			is_equal_approx(total, cap * Game.reach()), "it holds %.0f" % total)
		_check("N=%d: and the first turn is as far off as at any other count" % count,
			is_equal_approx(Game.sand, Tuning.cfg.sand_start), "%.0f on the clock" % Game.sand)

		# Turning the same way forever is the most generous route there is.
		var peak := 0.0
		for turn in 40:
			peak = maxf(peak, Game.sand)
			Game.drain(Game.sand)
			Game.rotate_glass(1)
		_check("N=%d: and no turn ever hands you more than a bulb" % count,
			peak <= cap + 1.0, "peaked at %.0f, a bulb being %.0f" % [peak, cap])


func _check(label: String, ok: bool, detail := "") -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_failures += 1
		print("  FAIL %s%s" % [label, "  (%s)" % detail if detail else ""])


func _finish() -> void:
	print("")
	print("All checks passed." if _failures == 0 else "%d check(s) FAILED." % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
