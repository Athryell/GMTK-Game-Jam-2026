@tool
## Monster: patrols along an axis and kills on contact, within its own plane only.
##
## Drawn as a clock, with a hand going round. The thing chasing you in a game
## about running out of time should look like the clock it is.
class_name Monster
extends PlaneArea

const FACE: Texture2D = preload("res://art/sprites/clock.png")

## The dial's size in the art. Only ever read as a ratio against the three below,
## so rescaling the sprite carries all four.
const ART_SIZE := 32.0
## The gold hub the hand turns on.
const ART_PIVOT := Vector2(16.0, 16.0)
## The hour ticks run from radius 6 out to 9.5; 7 stops the tip just inside them.
const ART_REACH := 7.0
const ART_WIDTH := 2.0

## Seconds for one full sweep, clockwise from twelve.
const HAND_PERIOD := 0.55

@export_group("Patrol")
@export var move_axis: PingPong.Axis = PingPong.Axis.X
## Patrol travel, in px, from the editor-placed position.
@export_range(0.0, 800.0, 1.0) var move_distance := 90.0
## Patrol speed, in px/s.
@export_range(0.0, 400.0, 1.0) var move_speed := 115.0
## Start offset in the cycle. All movers share one clock, so equal-period
## entities are locked in step at 0.
@export_range(0.0, 1.0, 0.05) var move_phase := 0.0

var _origin := Vector2.ZERO
var _elapsed := 0.0
## Where the hand has got to, in radians clockwise from twelve.
var _hand := 0.0


## NOTE: never set `plane` here. A scene only stores a property that differs from
## its DECLARED default, so a monster left on `BOTH` saves nothing, and an `_init`
## override would then pull it back to one plane at load.
func _init() -> void:
	# Exactly [constant ART_SIZE], so the dial is drawn one art px to one world px.
	size = Vector2(ART_SIZE, ART_SIZE)
	light_tint = Palette.MONSTER
	light_radius = 105.0
	# Kept low: at any strength the red wash swallows the clock face.
	light_energy = 0.2


func _ready() -> void:
	_origin = position
	# See `terrain.gd` for why this is per-node rather than a project default.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	super()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# Before the patrol guard: a monster told to hold still is still a clock.
	_hand = fmod(_hand + delta * TAU / HAND_PERIOD, TAU)
	queue_redraw()
	if move_axis == PingPong.Axis.NONE or move_speed <= 0.0:
		return
	_elapsed += delta
	position = _origin + PingPong.offset_vector(
		move_axis, _elapsed, move_distance, move_speed, move_phase)


func _touched(_player: Player) -> void:
	Game.kill()


## The dial, then the hand over it.
##
## Drawn SQUARE and centred on the hitbox rather than stretched to fill it: the
## art is a circle, and a non-square rect turns the clock into an egg. The square
## takes the hitbox's longer side, so it still covers everything that can kill
## you. Only reachable by resizing a monster, which breaks the
## one-art-px-to-one-world-px rule anyway.
func _paint() -> void:
	var span := maxf(size.x, size.y)
	var face := Rect2((size - Vector2(span, span)) * 0.5, Vector2(span, span))
	# White modulate is the sprite's own colours untouched; out of plane `_shade`
	# takes the alpha down and ghosts the whole dial at once.
	draw_texture_rect(FACE, face, false, _shade(Color.WHITE))

	# Struck last, so it sweeps over the dial rather than under it. One scale for
	# both axes, so the tip keeps to the ring of ticks the whole way round.
	var pivot := face.position + face.size * 0.5
	draw_line(pivot, pivot + Vector2.UP.rotated(_hand) * (span * ART_REACH / ART_SIZE),
		_shade(Palette.MONSTER),
		maxf(span * ART_WIDTH / ART_SIZE, 1.0), true)
