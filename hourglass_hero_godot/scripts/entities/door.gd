@tool
## The level exit. Belongs to a plane: a "back" door must be reached from back.
class_name Door
extends PlaneArea

## Breaths per second. Shared by the drawn halo and the light — they must match.
const PULSE_RATE := 3.0

## A 3×2 sheet of 32×32 frames, looped and stretched over the door's own rect.
## Greyscale on purpose, like [Bricks]: tinted with `Palette.DOOR` at draw time,
## so the portal is the same brass as the light it throws.
const TEXTURE: Texture2D = preload("res://art/sprites/dimensional_portal.png")
const FRAME_SIZE := Vector2(32.0, 32.0)
const FRAME_COLUMNS := 3
const FRAME_COUNT := 6
const FRAMES_PER_SECOND := 10.0
## The lit ring inside a cell — the widest it gets across the six frames. The rest
## of the cell is blank, and stretching that blank leaves the portal narrow and
## off-centre inside its own doorway.
const FRAME_CONTENT := Rect2(6.0, 1.0, 18.0, 30.0)

## The drawn glow around the mouth, in px, and how much of it a breath swings.
## Wider than the door: it is spill, not a rim.
const HALO_RADIUS := 46.0
const HALO_SWELL := 0.08
const HALO_ALPHA := 0.5


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
	var glow := HALO_RADIUS * (1.0 + HALO_SWELL * sin(_pulse * PULSE_RATE))
	draw_texture_rect(LightKit.falloff(),
		Rect2(size / 2.0 - Vector2(glow, glow), Vector2(glow, glow) * 2.0),
		false, Color(Palette.DOOR, HALO_ALPHA * colour.a))
	var frame := int(_pulse * FRAMES_PER_SECOND) % FRAME_COUNT
	var cell := Vector2(frame % FRAME_COLUMNS, frame / FRAME_COLUMNS) * FRAME_SIZE
	var source := Rect2(cell + FRAME_CONTENT.position, FRAME_CONTENT.size)
	draw_texture_rect_region(TEXTURE, Rect2(Vector2.ZERO, size), source,
		Color(Palette.DOOR, colour.a))
