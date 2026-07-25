@tool
## The level exit. Like everything else it belongs to a plane: a "back" door
## forces you to ARRIVE in the back plane, so you have to count your jumps.
class_name Door
extends PlaneArea

## Breaths per second of the halo and of the light, which have to agree or the
## door reads as two objects.
const PULSE_RATE := 3.0


var _pulse := 0.0


func _init() -> void:
	size = Vector2(34.0, 64.0)
	light_tint = Palette.DOOR
	light_radius = 190.0
	light_energy = 1.25
	# The halo breathes, and the light breathes with it. Handing the rate to the
	# light rather than driving its energy from here keeps the one formula that
	# turns a scale into a brightness inside `EntityLight`, where it belongs.
	light_pulse_rate = PULSE_RATE
	light_pulse_depth = 0.28


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_pulse += delta
	queue_redraw()


func _touched(_player: Player) -> void:
	if Game.status == Game.Status.PLAY:
		Game.win()


func _draw() -> void:
	var colour := _shade(Palette.DOOR)
	# A breathing halo: the exit catches the eye even from far away.
	var glow := 6.0 + 3.0 * sin(_pulse * PULSE_RATE)
	draw_rect(Rect2(Vector2(-glow, -glow), size + Vector2(glow, glow) * 2.0),
		Color(Palette.DOOR, 0.18 * colour.a))
	draw_rect(Rect2(Vector2.ZERO, size), colour)
	draw_rect(Rect2(Vector2(4.0, 4.0), size - Vector2(8.0, 8.0)), colour.darkened(0.55))
	draw_circle(Vector2(size.x * 0.75, size.y * 0.55), 3.0, colour)
