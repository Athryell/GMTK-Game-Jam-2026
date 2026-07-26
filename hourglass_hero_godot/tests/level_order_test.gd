## Level order test: which number a level's filename carries and what order the
## menu puts them in, with nothing rendered and no game running.
##
##   godot --headless tests/level_order_test.tscn
extends Node

var _failures := 0


func _ready() -> void:
	_numbers()
	_order()
	_finish()


func _numbers() -> void:
	_check("level_04_the_spring is 4",
		Level.number_from_path("res://scenes/levels/level_04_the_spring.tscn") == 4)
	_check("level_100_test is 100",
		Level.number_from_path("level_100_test.tscn") == 100)
	_check("a name with no number lands after every numbered one",
		Level.number_from_path("sandbox.tscn") > 1000)


func _order() -> void:
	var names: Array[String] = [
		"level_10_the_well.tscn",
		"level_100_test.tscn",
		"level_09_midnight.tscn",
		"level_02_no_rush.tscn",
		"level_02_metronome.tscn",
	]
	var expected: Array[String] = [
		"level_02_metronome.tscn",
		"level_02_no_rush.tscn",
		"level_09_midnight.tscn",
		"level_10_the_well.tscn",
		"level_100_test.tscn",
	]
	names.sort_custom(Game.level_before)
	_check("numbers order the list, and ties fall back on the name",
		names == expected, ", ".join(names))

# ----- Harness ---------------------------------------------------------------

func _check(what: String, passed: bool, detail := "") -> void:
	if passed:
		print("ok   %s" % what)
		return
	_failures += 1
	print("FAIL %s%s" % [what, "" if detail.is_empty() else " (%s)" % detail])


func _finish() -> void:
	if _failures == 0:
		print("All checks passed.")
	else:
		print("%d check(s) failed." % _failures)
	get_tree().quit(0 if _failures == 0 else 1)
