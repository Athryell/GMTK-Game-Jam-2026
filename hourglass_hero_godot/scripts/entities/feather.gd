@tool
## A feather lying in the level: pick it up and you carry ONE mid-air jump.
##
## The charge is spent the moment you use it and is never handed back — not by
## landing, not by a spring. So the level's question is not "can I double jump?"
## but "which gap do I spend it on?".
class_name Feather
extends PlaneArea

## A coloured sprite, not a greyscale mask like the door's: it takes the ghost
## alpha and no tint.
const TEXTURE: Texture2D = preload("res://art/sprites/feather.png")

## Idle bob, in px, and in breaths per second.
const BOB := 3.5
const BOB_RATE := 2.2

const HALO_RADIUS := 26.0
const HALO_ALPHA := 0.45

var _pulse := 0.0


func _init() -> void:
	# Wider than the 16×16 sprite, so it reads as an item and not as a speck of
	# scenery.
	size = Vector2(24.0, 24.0)
	# The spring's family, for the spring's reason: height that costs no sand.
	light_tint = Palette.SPRING
	light_radius = 110.0
	light_energy = 0.85
	light_pulse_rate = BOB_RATE
	light_pulse_depth = 0.22


func _ready() -> void:
	super()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_pulse += delta
	queue_redraw()


func _touched(player: Player) -> void:
	player.take_feather()
	Burst.ring(get_parent(), global_position + size / 2.0, Palette.SPRING)
	Audio.sfx("gravity_up")
	queue_free()


func _paint() -> void:
	var colour := _shade(Color.WHITE)
	var lift := BOB * sin(_pulse * BOB_RATE)
	draw_texture_rect(LightKit.falloff(),
		Rect2(size / 2.0 - Vector2(HALO_RADIUS, HALO_RADIUS - lift),
			Vector2(HALO_RADIUS, HALO_RADIUS) * 2.0),
		false, Color(Palette.SPRING, HALO_ALPHA * colour.a))
	draw_texture_rect(TEXTURE, Rect2(Vector2(0.0, lift), size), false, colour)
