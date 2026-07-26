## Backdrop test: how far the painted layers trail a camera that moves down,
## with nothing rendered and no game running.
##
##   godot --headless tests/backdrop_test.tscn
extends Node

var _failures := 0


func _ready() -> void:
	_lag()
	_finish()


func _lag() -> void:
	_check("standing at the datum, the art sits on its anchor",
		is_equal_approx(BackdropLayer.vertical_lag(0.0), 0.0))

	var shallow := Backdrop.ART_DROP / Backdrop.VERTICAL_SCROLL * 0.5
	_check("a short drop trails at the parallax rate",
		is_equal_approx(BackdropLayer.vertical_lag(shallow),
			shallow * Backdrop.VERTICAL_SCROLL))

	_check("a long fall never lifts the art off its anchor by more than ART_DROP",
		is_equal_approx(BackdropLayer.vertical_lag(100000.0), Backdrop.ART_DROP))

	_check("climbing above the datum plants the art deeper, uncapped",
		is_equal_approx(BackdropLayer.vertical_lag(-1000.0),
			-1000.0 * Backdrop.VERTICAL_SCROLL))

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
