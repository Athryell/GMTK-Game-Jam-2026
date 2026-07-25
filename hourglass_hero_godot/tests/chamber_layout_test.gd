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
	_roles()
	_pour_map()
	_trefoil_lesson()
	_quarters_lesson()
	_finish()


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

	_check("N=4: exactly two chambers are sealed",
		ChamberLayout.lowers(4).size() == 1 and ChamberLayout.uppers(4).size() == 1)
	_check("every glass has exactly one chamber that drains",
		ChamberLayout.uppers(2).size() == 1 and ChamberLayout.uppers(3).size() == 1
			and ChamberLayout.uppers(4).size() == 1)


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
