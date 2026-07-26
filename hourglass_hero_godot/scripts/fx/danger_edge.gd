## The red border that closes in as the sand runs out: bands of [constant
## Palette.SAND_LOW] fading inwards from the four edges, breathing on their own
## clock and trembling a little.
##
## Drawn on the HUD's canvas, not in the world, so the camera shake that comes
## with the same danger does not drag it around.
extends Control

## Bands from the edge inwards. Enough that the ramp reads as a gradient rather
## than as steps at the depths below; more only costs draw calls.
const BANDS := 14
## How far the border trembles, in px.
const TREMBLE := 2.5
## Two mismatched rates, so the two axes never come back in step.
const TREMBLE_RATES := Vector2(37.0, 29.0)

var _clock := 0.0


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	# Death stops the drain, which would otherwise leave the border pinned on
	# through the death screen.
	if Game.status != Game.Status.PLAY:
		return
	# Squared, so the border only really arrives at the very end.
	var fear := Game.danger()
	var glow := fear * fear
	if glow <= 0.0:
		return

	var cfg := Tuning.cfg
	# The pulse quickens with the danger: a slow breath at the warning, a
	# heartbeat when there is nothing left.
	var beat := 0.5 + 0.5 * sin(_clock * TAU * cfg.danger_edge_pulse * (0.6 + fear))
	var peak := cfg.danger_edge_alpha * glow * (0.6 + 0.4 * beat)
	var depth := cfg.danger_edge_depth * (0.55 + 0.45 * glow)
	var step := depth / float(BANDS)
	var shiver := Vector2(
		sin(_clock * TREMBLE_RATES.x), cos(_clock * TREMBLE_RATES.y)) * TREMBLE * glow

	for i in BANDS:
		var inset := (float(i) + 0.5) * step
		var fade := 1.0 - float(i) / float(BANDS)
		var rect := Rect2(Vector2(inset, inset) + shiver, size - Vector2(inset, inset) * 2.0)
		draw_rect(rect, Color(Palette.SAND_LOW, peak * fade * fade), false, step)
