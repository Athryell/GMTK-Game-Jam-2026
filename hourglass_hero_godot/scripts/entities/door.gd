@tool
## The level exit. Belongs to a plane: a "back" door must be reached from back.
class_name Door
extends PlaneArea

## Breaths per second. Shared by the drawn halo and the light — they must match.
const PULSE_RATE := 3.0

## The exit is a portal rather than a panel: a 3×2 sheet of 32×32 frames, looped
## and stretched over the door's own rect.
const TEXTURE: Texture2D = preload("res://art/sprites/dimensional_portal.png")
const FRAME_SIZE := Vector2(32.0, 32.0)
const FRAME_COLUMNS := 3
const FRAME_COUNT := 6
const FRAMES_PER_SECOND := 10.0


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
	var frame := int(_pulse * FRAMES_PER_SECOND) % FRAME_COUNT
	var source := Rect2(
		Vector2(frame % FRAME_COLUMNS, frame / FRAME_COLUMNS) * FRAME_SIZE, FRAME_SIZE)
	draw_texture_rect_region(TEXTURE, Rect2(Vector2.ZERO, size), source,
		Color(1.0, 1.0, 1.0, colour.a))
