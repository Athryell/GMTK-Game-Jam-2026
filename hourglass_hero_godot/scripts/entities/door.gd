@tool
## The level exit. Belongs to a plane: a "back" door must be reached from back.
class_name Door
extends PlaneArea

## Breaths per second. Shared by the drawn halo and the light — they must match.
const PULSE_RATE := 3.0


var _pulse := 0.0


func _init() -> void:
	size = Vector2(34.0, 64.0)
	light_tint = Palette.DOOR
	light_radius = 190.0
	light_energy = 1.25
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
	var glow := 6.0 + 3.0 * sin(_pulse * PULSE_RATE)
	draw_rect(Rect2(Vector2(-glow, -glow), size + Vector2(glow, glow) * 2.0),
		Color(Palette.DOOR, 0.18 * colour.a))
	# The frame only; the panel inside it is a recess, not a silhouette.
	Outline.rect(self, Rect2(Vector2.ZERO, size), colour.a)
	draw_rect(Rect2(Vector2.ZERO, size), colour)
	draw_rect(Rect2(Vector2(4.0, 4.0), size - Vector2(8.0, 8.0)), colour.darkened(0.55))
	draw_circle(Vector2(size.x * 0.75, size.y * 0.55), 3.0, colour)
