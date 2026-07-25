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


## The three-chamber lesson: turning the same way visits every chamber; going
## back and forth starves one of them for good.
func _trefoil_lesson() -> void:
	var visited := {}
	var slot := 0
	for turn in 3:
		slot = posmod(slot + 1, 3)
		visited[slot] = true
	_check("N=3: three turns the same way visit all three chambers",
		visited.size() == 3)

	visited = {}
	slot = 0
	for turn in 6:
		slot = posmod(slot + (1 if turn % 2 == 0 else -1), 3)
		visited[slot] = true
	_check("N=3: alternating never reaches the third chamber", visited.size() == 2,
		"reached %d chambers" % visited.size())


## The four-chamber lesson: the sand you drained is whole, but it has to travel
## through a sealed side chamber, so it is two turns away — and turning back
## undoes exactly the turn before it.
func _quarters_lesson() -> void:
	var bottom := ChamberLayout.lowers(4)[0]
	var after_one := posmod(bottom + 1, 4)
	var after_two := posmod(bottom + 2, 4)
	_check("N=4: one turn parks the drained sand in a sealed chamber",
		ChamberLayout.role(4, after_one) == ChamberLayout.Role.LEVEL)
	_check("N=4: two turns the same way bring it back to the top",
		ChamberLayout.role(4, after_two) == ChamberLayout.Role.UPPER)

	var slot := 1
	slot = posmod(slot + 1, 4)
	slot = posmod(slot - 1, 4)
	_check("N=4: turning back undoes the turn exactly", slot == 1)


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
