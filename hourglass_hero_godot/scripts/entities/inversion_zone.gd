@tool
## A region where the hourglass runs backwards: sand climbs from the bottom
## bulb to the top one, and an empty BOTTOM bulb kills.
##
## Nothing here touches physics — you fall, jump and bounce exactly as outside.
##
## Unlike every other [PlaneArea] this is a state, not an event, so it ignores
## `_touched` and polls instead: dying or reloading inside a zone cannot leave a
## stale "you are inside" flag set.
class_name InversionZone
extends PlaneArea

## Large and outlined: the zone must read as a place, not as a thing to collect.
## Heavier than it looks — three of the four skies are hot and bright, and a 0.10
## wash vanished into them whatever its hue.
const FIELD_ALPHA := 0.2
const EDGE_ALPHA := 0.8
## Multiplier while the zone actually holds the player. The sand takes half a
## second to turn round, so the zone has to say so on the frame you cross it.
## Past about 2 the held field is solid enough to swallow the player.
const HELD_BOOST := 1.8
## Rising motes: the only part that says "upward" while you stand still.
const MOTE_COLUMNS := 5
const MOTE_SPEED := 110.0 ## px per second
const MOTE_LENGTH := 16.0

var _phase := 0.0


func _init() -> void:
	# Tall enough to stand in with room to panic.
	size = Vector2(220.0, 240.0)
	light_tint = Palette.FLIP_PAD
	light_radius = 200.0
	light_energy = 0.5


func _ready() -> void:
	super()
	# In code so `Game.INVERSION_GROUP` is the only place the string exists.
	add_to_group(Game.INVERSION_GROUP)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_phase = fmod(_phase + delta * MOTE_SPEED, size.y)
	queue_redraw()


## True while the player stands inside AND this zone is in their plane. The mask
## is `Layers.PLAYER`, so an overlapping body can only be the player.
func contains_player() -> bool:
	return _active and has_overlapping_bodies()


func _paint() -> void:
	# The light stays gold in every theme; the field is the theme's own, since it
	# is what has to stand out against the sky.
	var tint := _shade(Palette.inversion(Level.group_of(self)))
	var boost := HELD_BOOST if contains_player() else 1.0
	var edge := Color(tint, minf(tint.a * EDGE_ALPHA * boost, 1.0))
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, Color(tint, tint.a * FIELD_ALPHA * boost))
	draw_rect(bounds, edge, false, 2.0)

	# Evenly spread so the column never reads as one object drifting past.
	for i in MOTE_COLUMNS:
		var x := size.x * (i + 0.5) / MOTE_COLUMNS
		var travelled := fmod(_phase + size.y * i / float(MOTE_COLUMNS), size.y)
		var head := size.y - travelled
		draw_line(Vector2(x, head), Vector2(x, minf(head + MOTE_LENGTH, size.y)),
			edge, 2.0, true)
