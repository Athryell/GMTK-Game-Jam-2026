## Run clock test: how a duration is written out. Pure arithmetic, exits 1 on
## failure.
##
##   godot --headless tests/run_clock_test.tscn
extends Node

var _failures := 0


func _ready() -> void:
	_check("a fresh run reads zero", Game.format_time(0.0) == "0:00.00",
		Game.format_time(0.0))
	_check("centiseconds", Game.format_time(1.23) == "0:01.23",
		Game.format_time(1.23))
	_check("the minute rolls over", Game.format_time(60.0) == "1:00.00",
		Game.format_time(60.0))
	_check("seconds are two digits", Game.format_time(65.5) == "1:05.50",
		Game.format_time(65.5))
	# The failure this guards: rounding here would print "0:60.00" a frame before
	# the minute, and the last frame of a run would read more than the total.
	_check("just under a minute stays in it", Game.format_time(59.999) == "0:59.99",
		Game.format_time(59.999))
	_check("minutes are not capped", Game.format_time(12 * 60.0 + 4.37) == "12:04.37",
		Game.format_time(12 * 60.0 + 4.37))
	_check("an hour keeps counting in minutes", Game.format_time(3600.0) == "60:00.00",
		Game.format_time(3600.0))
	_check("a negative duration cannot be printed", Game.format_time(-5.0) == "0:00.00",
		Game.format_time(-5.0))

	Game.run_time = 12.5
	Game.start_run(0)
	_check("starting a run puts the clock back", is_zero_approx(Game.run_time),
		"%f" % Game.run_time)

	_finish()


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
