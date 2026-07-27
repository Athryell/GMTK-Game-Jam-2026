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
	Game.run_deaths = 7
	Game.start_run(0)
	_check("starting a run puts the clock back", is_zero_approx(Game.run_time),
		"%f" % Game.run_time)
	_check("starting a run puts the death count back", Game.run_deaths == 0,
		"%d" % Game.run_deaths)

	_die()
	_die()
	_check("every death is counted once", Game.run_deaths == 2, "%d" % Game.run_deaths)
	Game.start_level(Game.level_index, true)
	_check("a retry keeps the run's toll", Game.run_deaths == 2, "%d" % Game.run_deaths)
	Game.start_level(Game.level_index + 1)
	_check("the next level keeps the run's toll", Game.run_deaths == 2,
		"%d" % Game.run_deaths)

	# The teaching level: it kills you to make its point, and the run is not
	# charged for it — but the lock still has to be spent, or the jump never comes
	# back.
	Game.counts_towards_run = false
	Game.jump_locked_first_life = true
	Game.level_deaths = 0
	_die()
	_check("an unscored level does not add to the run's toll", Game.run_deaths == 2,
		"%d" % Game.run_deaths)
	_check("an unscored death still hands the jump back", Game.jump_enabled)
	Game.counts_towards_run = true

	_finish()


## `set_status` only counts a change, so a second death has to be preceded by
## coming back to life.
func _die() -> void:
	Game.set_status(Game.Status.DEAD)
	Game.set_status(Game.Status.PLAY)


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
