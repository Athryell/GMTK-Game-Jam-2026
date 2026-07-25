@tool
## A region where the hourglass runs backwards: sand climbs from the bottom
## bulb to the top one, and an empty BOTTOM bulb kills.
##
## The fiction is gravity, but nothing here touches physics — you fall, jump
## and bounce exactly as outside. Only the sand turns round, which makes a zone
## both a refuel station and a trap, told apart by nothing but how long you
## stay.
##
## Unlike every other [PlaneArea] this is a state, not an event, so it ignores
## `_touched` and polls instead. Polling has no state to corrupt: dying or
## reloading inside a zone cannot leave a stale "you are inside" flag set.
##
## The node's origin is the TOP-LEFT corner of `size`, like every other solid.
class_name InversionZone
extends PlaneArea

## The zone must read as a place, not as a thing to collect: the gold family is
## otherwise spent on small bright solids, so this stays large, faint, outlined.
const FIELD_ALPHA := 0.10
const EDGE_ALPHA := 0.5
## Multiplier while the zone actually holds the player. The turn takes half a
## second, so something has to say "this is what started it" on the frame you
## cross the line; without it the glass simply begins tipping for no visible
## reason.
const HELD_BOOST := 2.6
## Rising motes: the only part that says "upward" while you stand still.
const MOTE_COLUMNS := 5
const MOTE_SPEED := 110.0 ## px per second
const MOTE_LENGTH := 16.0

var _phase := 0.0


func _init() -> void:
	# Tall enough to stand in with room to panic: a zone crossed by accident
	# teaches nothing.
	size = Vector2(220.0, 240.0)
	light_tint = Palette.FLIP_PAD
	light_radius = 200.0
	light_energy = 0.5


func _ready() -> void:
	super()
	# In code so `Game.INVERSION_GROUP` is the only place the string exists; a
	# group name typed into a .tscn can drift from the constant unnoticed.
	add_to_group(Game.INVERSION_GROUP)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_phase = fmod(_phase + delta * MOTE_SPEED, size.y)
	queue_redraw()


## True while the player stands inside AND this zone is in their plane.
##
## No player reference is needed: the mask is `Layers.PLAYER`, so an overlapping
## body can only be the player, and `PlaneArea` already drops `monitoring` out
## of plane, so a ghost reports nothing.
func contains_player() -> bool:
	return _active and has_overlapping_bodies()


func _draw() -> void:
	var tint := _shade(Palette.FLIP_PAD)
	var boost := HELD_BOOST if contains_player() else 1.0
	var edge := Color(tint, minf(tint.a * EDGE_ALPHA * boost, 1.0))
	var bounds := Rect2(Vector2.ZERO, size)
	draw_rect(bounds, Color(tint, tint.a * FIELD_ALPHA * boost))
	draw_rect(bounds, edge, false, 2.0)

	# Evenly spread so the column never reads as one object drifting past, and
	# clipped to the zone so the boundary stays the strongest line in the drawing.
	for i in MOTE_COLUMNS:
		var x := size.x * (i + 0.5) / MOTE_COLUMNS
		var travelled := fmod(_phase + size.y * i / float(MOTE_COLUMNS), size.y)
		var head := size.y - travelled
		draw_line(Vector2(x, head), Vector2(x, minf(head + MOTE_LENGTH, size.y)),
			edge, 2.0, true)
