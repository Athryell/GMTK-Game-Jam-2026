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

## The hitbox, a slit on the lit ring rather than the whole doorway: the ring is
## 18 art px of a 34 px cell, so a full-rect hitbox cleared the level a body's
## width before the glass reached the light.
const MOUTH := Vector2(12.0, 46.0)

const SWALLOW_FLARE := 0.7
const SWALLOW_SPEED_UP := 3.0


var _pulse := 0.0
## Where the ring's animation has got to, in frames.
var _spin := 0.0
var _swallow := 0.0
var _swallowing := false


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
	if _swallowing:
		_swallow = minf(_swallow + delta / Player.SWALLOW_TIME, 1.0)
	# Counted rather than read off `_pulse`, or the frame jumps when the rate does.
	_spin += delta * FRAMES_PER_SECOND * (1.0 + SWALLOW_SPEED_UP * _swallow)
	queue_redraw()


## Won on the spot: the level-clear delay is the cover the swallow plays under.
func _touched(player: Player) -> void:
	if Game.status != Game.Status.PLAY:
		return
	Audio.sfx("portal")
	_swallowing = true
	player.swallowed_by(global_position + size / 2.0)
	Game.win()


## See [constant MOUTH].
func _apply_size() -> void:
	queue_redraw()
	if not is_node_ready():
		return
	var rect := _shape.shape as RectangleShape2D
	rect.size = MOUTH
	_shape.position = size / 2.0


func _paint() -> void:
	var colour := _shade(Palette.DOOR)
	# Half a breath, so the mouth gulps as the glass goes down and then settles.
	var gulp := 1.0 + SWALLOW_FLARE * sin(_swallow * PI)
	var glow := HALO_RADIUS * gulp * (1.0 + HALO_SWELL * sin(_pulse * PULSE_RATE))
	draw_texture_rect(LightKit.falloff(),
		Rect2(size / 2.0 - Vector2(glow, glow), Vector2(glow, glow) * 2.0),
		false, Color(Palette.DOOR, minf(HALO_ALPHA * gulp, 1.0) * colour.a))
	var frame := int(_spin) % FRAME_COUNT
	var cell := Vector2(frame % FRAME_COLUMNS, frame / FRAME_COLUMNS) * FRAME_SIZE
	var source := Rect2(cell + FRAME_CONTENT.position, FRAME_CONTENT.size)
	draw_texture_rect_region(TEXTURE, Rect2(Vector2.ZERO, size), source,
		Color(Palette.DOOR, colour.a))
